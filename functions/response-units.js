const {randomUUID, createHash} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {access} = require('./statistics-handlers');
const {orgId} = require('./statistics-history');
const {active} = require('./contribution-statistics');
const id = v => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const text = (v, max, required=false) => typeof v === 'string' && v.length <= max && (!required || v.trim().length > 0);
const ids = (v, max) => Array.isArray(v) && v.length <= max && v.every(id) && new Set(v).size === v.length;
const key = (kind, value) => `${kind}_${createHash('sha256').update(value).digest('hex')}`;
const linkKey = (unit, resource) => key('link', JSON.stringify([unit, resource]));
const ms = v => v?.toMillis?.() ?? null;
const fail = message => { throw new HttpsError('invalid-argument', message); };
function validate(d, extra) {
  if (!d || Object.keys(d).some(k => !['organizationId', 'id', 'expectedRevision', ...extra].includes(k)) ||
      !id(d.id) || !Number.isSafeInteger(d.expectedRevision) || d.expectedRevision < 0) fail('Kontrolli vormi andmeid.');
}
function coordinates(latitude, longitude) {
  if (latitude === null && longitude === null) return null;
  if (typeof latitude !== 'number' || typeof longitude !== 'number' ||
      !Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      Math.abs(latitude) > 90 || Math.abs(longitude) > 180) fail('Sisesta mõlemad koordinaadid või jäta mõlemad tühjaks.');
  return {latitude, longitude};
}
function createResponseUnitHandlers({db, timestamp, geoPoint, fromMillis, now=Date.now}) {
  const txDb = tx => ({doc:path => ({get:() => tx.get(db.doc(path))})});
  async function query(tx, collection, field, value, maximum=300) {
    const snapshot = await tx.get(db.collection(collection).where(field,'==',value).limit(maximum+1));
    if (snapshot.size > maximum) throw new HttpsError('resource-exhausted','Andmeid on selle vaate jaoks liiga palju. Vajalik on lehekülgedega laadimine.');
    return snapshot.docs;
  }
  async function own(tx, path, org, revision) {
    const ref=db.doc(path), snapshot=await tx.get(ref), before=snapshot.data();
    if (before && before.organizationId !== org) throw new HttpsError('permission-denied','Kirje ei kuulu sellele ühingule.');
    if ((before?.revision ?? 0) !== revision) throw new HttpsError('aborted','Andmeid on vahepeal muudetud. Laadi vaade uuesti.');
    return {ref,before};
  }
  function changed(tx, actor, request, action, targetId, before, after) {
    // Serializes base/unit changes, including archive vs. concurrent unit creation.
    tx.update(db.doc(`commands/${actor.org}`), {unitManagementRevision:(actor.organization.unitManagementRevision || 0)+1});
    tx.create(db.doc(`platformAudit/${randomUUID()}`), {organizationId:actor.org,
      action,targetId,before:before || null,after,createdBy:request.auth.uid,createdAt:timestamp()});
  }
  async function organizationBase(tx, actor) {
    let baseId=actor.organization.primaryRescueBaseId;
    if (baseId != null && !id(baseId)) throw new HttpsError('failed-precondition','Ühingu asukoha seos vajab parandamist.');
    if (baseId == null) {
      const bases=await tx.get(db.collection('rescueBases').where('organizationId','==',actor.org).limit(2));
      if (bases.size>1) throw new HttpsError('failed-precondition','Ühingul on mitu varasemat päästebaasi. Põhibaasi seos vajab määramist.');
      baseId=bases.docs[0]?.id ?? key('orgbase',actor.org);
    }
    const ref=db.doc(`rescueBases/${baseId}`), before=(await tx.get(ref)).data();
    if ((before && before.organizationId!==actor.org) || (actor.organization.primaryRescueBaseId && !before)) {
      throw new HttpsError('failed-precondition','Ühingu asukoha seos vajab parandamist.');
    }
    return {ref,before};
  }
  function locationFields(point, verified, before, uid) {
    const keep=point && verified && before?.positionVerifiedAt &&
      before.position?.latitude===point.latitude && before.position?.longitude===point.longitude;
    return {
      position:point ? geoPoint(point.latitude,point.longitude) : null,
      positionSource:point ? 'manual' : null,
      positionVerifiedAt:point && verified ? (keep ? before.positionVerifiedAt : timestamp()) : null,
      positionVerifiedBy:point && verified ? (keep ? before.positionVerifiedBy ?? uid : uid) : null,
    };
  }
  async function resources(tx, org, members, vessels) {
    const memberDocs = [];
    for (const uid of members) {
      const m=(await tx.get(db.doc(`memberships/${uid}_${org}`))).data();
      if (!active(m) || m.userId !== uid || orgId(m) !== org) fail('Vali ainult selle ühingu aktiivsed liikmed.');
      memberDocs.push({kind:'member',resourceId:uid,key:key('member',uid),identityVerified:true});
    }
    const vesselDocs=[];
    for (const equipmentId of vessels) {
      const e=(await tx.get(db.doc(`equipment/${equipmentId}`))).data();
      if (orgId(e) !== org || e?.scope === 'personal' || e?.category !== 'vessel') fail('Vali selle ühingu varustuses olev alus.');
      const identity=(await tx.get(db.doc(`vesselIdentities/${equipmentId}`))).data();
      const verified=identity?.verified === true && identity.organizationId === org && id(identity.physicalResourceId);
      vesselDocs.push({kind:'vessel',resourceId:equipmentId,
        key:verified ? key('vessel',identity.physicalResourceId) : key('unverifiedVessel',equipmentId),
        identityVerified:!!verified,physicalResourceId:verified ? identity.physicalResourceId : null});
    }
    if (new Set(vesselDocs.map(v=>v.key)).size !== vesselDocs.length) fail('Sama füüsilist alust ei saa lisada mitme kirjena.');
    return [...memberDocs,...vesselDocs];
  }
  return {
    getOrganizationMapLocation: request => db.runTransaction(async tx=>{
      const actor=await access(txDb(tx),request,{adminOnly:true});
      const {before:b}=await organizationBase(tx,actor);
      return {address:b?.address ?? '',latitude:b?.position?.latitude ?? null,
        longitude:b?.position?.longitude ?? null,positionVerified:b?.positionVerifiedAt!=null,revision:b?.revision ?? 0};
    }),
    saveOrganizationMapLocation: async request=>{
      const d=request.data || {};
      // The organization determines the target; clients cannot choose another base or change its status.
      validate({...d,id:'organization-location'},['address','latitude','longitude','positionVerified']);
      if ('id' in d || !text(d.address,300) || typeof d.positionVerified!=='boolean') fail('Kontrolli asukoha andmeid.');
      const point=coordinates(d.latitude,d.longitude);
      if (!point && d.positionVerified) fail('Puuduvat asukohta ei saa kinnitada.');
      return db.runTransaction(async tx=>{
        const actor=await access(txDb(tx),request,{adminOnly:true});
        const {ref,before}=await organizationBase(tx,actor);
        if ((before?.revision ?? 0)!==d.expectedRevision) throw new HttpsError('aborted','Asukohta on vahepeal muudetud. Laadi andmed uuesti.');
        const value={organizationId:actor.org,address:d.address.trim(),
          ...locationFields(point,d.positionVerified,before,request.auth.uid),
          revision:d.expectedRevision+1,updatedBy:request.auth.uid,updatedAt:timestamp(),
          ...(before ? {} : {name:actor.organization.name || 'Ühing',active:true,createdBy:request.auth.uid,createdAt:timestamp()})};
        tx.set(ref,value,{merge:true});
        tx.update(db.doc(`commands/${actor.org}`),{primaryRescueBaseId:ref.id});
        changed(tx,actor,request,'organization.mapLocation',ref.id,before,value);
        return {saved:true,revision:value.revision};
      });
    },
    getOrganizationUnits: request => db.runTransaction(async tx => {
      const actor=await access(txDb(tx),request,{adminOnly:true});
      const org=actor.org;
      const bases=await query(tx,'rescueBases','organizationId',org,100);
      const units=await query(tx,'responseUnits','organizationId',org,100);
      const modern=await query(tx,'memberships','organizationId',org);
      const legacy=await query(tx,'memberships','commandId',org);
      const equipmentModern=await query(tx,'equipment','organizationId',org);
      const equipmentLegacy=await query(tx,'equipment','commandId',org);
      const members=[...new Map([...modern,...legacy].map(d=>[d.id,d])).values()]
        .filter(d=>orgId(d.data())===org && active(d.data()) && d.id===`${d.data().userId}_${org}`)
        .map(d=>({id:d.data().userId,name:d.data().displayName || 'Liige',level:d.data().seaRescueLevel || 'none'}));
      const vessels=[];
      for (const doc of new Map([...equipmentModern,...equipmentLegacy].map(d=>[d.id,d])).values()) {
        const e=doc.data();
        if (orgId(e)!==org || e.scope==='personal' || e.category!=='vessel') continue;
        const identity=(await tx.get(db.doc(`vesselIdentities/${doc.id}`))).data();
        vessels.push({id:doc.id,name:e.name || 'Alus',status:e.status || 'unknown',
          identityVerified:identity?.verified===true && identity.organizationId===org && id(identity.physicalResourceId)});
      }
      const roster=await query(tx,'unitRoster','organizationId',org,6000);
      const gear=await query(tx,'unitEquipment','organizationId',org,1000);
      const allocations=await query(tx,'resourceAllocations','organizationId',org,1000);
      const serverNowMs=now();
      return {serverNowMs,bases:bases.map(d=>{const b=d.data();return {id:d.id,name:b.name || 'Päästebaas',address:b.address || '',
        latitude:b.position?.latitude ?? null,longitude:b.position?.longitude ?? null,
        positionVerified:b.positionVerifiedAt!=null,active:b.active===true,revision:b.revision ?? 0};}),
        units:units.map(d=>{const u=d.data();return {id:d.id,name:u.name || 'Üksus',baseId:u.baseId || '',active:u.active===true,
          enabledServices:u.enabledServices || [],contactName:u.contactName || '',contactPhone:u.contactPhone || '',revision:u.revision ?? 0,
          memberIds:roster.filter(r=>r.data().unitId===d.id).map(r=>r.data().userId),
          vesselIds:gear.filter(r=>r.data().unitId===d.id).map(r=>r.data().equipmentId),
          allocations:allocations.filter(r=>r.data().unitId===d.id && ms(r.data().validUntil)>serverNowMs)
            .map(r=>({kind:r.data().kind,resourceId:r.data().resourceId,validUntilMs:ms(r.data().validUntil),identityVerified:r.data().identityVerified===true}))};}),members,vessels};
    }),
    saveRescueBase: async request => {
      const d=request.data || {};
      validate(d,['name','address','latitude','longitude','positionVerified','active']);
      if (!text(d.name,120,true) || !text(d.address,300) || typeof d.active!=='boolean' || typeof d.positionVerified!=='boolean') fail('Kontrolli päästebaasi nime ja aadressi.');
      const point=coordinates(d.latitude,d.longitude);
      if (!point && d.positionVerified) fail('Puuduvat asukohta ei saa kinnitada.');
      return db.runTransaction(async tx=>{
        const actor=await access(txDb(tx),request,{adminOnly:true});
        const {ref,before}=await own(tx,`rescueBases/${d.id}`,actor.org,d.expectedRevision);
        if (!before && (await query(tx,'rescueBases','organizationId',actor.org,100)).length>=100) throw new HttpsError('resource-exhausted','Ühingu päästebaaside piir (100) on täis.');
        if (!d.active) {
          const linked=await query(tx,'responseUnits','baseId',d.id,100);
          if (linked.some(u=>u.data().active===true)) throw new HttpsError('failed-precondition','Baasis on aktiivne üksus. Muuda esmalt üksuse baasi või peata üksus.');
        }
        const value={organizationId:actor.org,name:d.name.trim(),address:d.address.trim(),active:d.active,
          ...locationFields(point,d.positionVerified,before,request.auth.uid),
          revision:d.expectedRevision+1,updatedBy:request.auth.uid,updatedAt:timestamp(),
          ...(before ? {} : {createdBy:request.auth.uid,createdAt:timestamp()})};
        tx.set(ref,value,{merge:true});
        changed(tx,actor,request,'rescueBase.saved',d.id,before,value);
        return {saved:true,id:d.id,revision:value.revision};
      });
    },
    saveResponseUnit: async request => {
      const d=request.data || {};
      validate(d,['baseId','name','active','enabledServices','contactName','contactPhone','memberIds','vesselIds']);
      if (!id(d.baseId) || !text(d.name,120,true) || !text(d.contactName,120) || !text(d.contactPhone,60) ||
          typeof d.active!=='boolean' || !ids(d.enabledServices,2) || !d.enabledServices.length ||
          d.enabledServices.some(s=>!['sar','tross'].includes(s)) || !ids(d.memberIds,50) || !ids(d.vesselIds,10)) fail('Kontrolli üksuse nime, teenuseid ja koosseisu.');
      return db.runTransaction(async tx=>{
        const actor=await access(txDb(tx),request,{adminOnly:true});
        const {ref,before}=await own(tx,`responseUnits/${d.id}`,actor.org,d.expectedRevision);
        if (!before && (await query(tx,'responseUnits','organizationId',actor.org,100)).length>=100) throw new HttpsError('resource-exhausted','Ühingu üksuste piir (100) on täis.');
        const base=(await tx.get(db.doc(`rescueBases/${d.baseId}`))).data();
        if (base?.organizationId!==actor.org || base.active!==true) fail('Vali selle ühingu aktiivne päästebaas.');
        await resources(tx,actor.org,d.memberIds,d.vesselIds);
        const roster=await query(tx,'unitRoster','unitId',d.id,50);
        const gear=await query(tx,'unitEquipment','unitId',d.id,10);
        const allocated=await query(tx,'resourceAllocations','unitId',d.id,60);
        const at=now();
        if (allocated.some(a=>ms(a.data().validUntil)>at && (!d.active ||
            !(a.data().kind==='member' ? d.memberIds : d.vesselIds).includes(a.data().resourceId)))) {
          throw new HttpsError('failed-precondition','Vabasta eemaldatavad ressursid enne koosseisu muutmist või üksuse peatamist.');
        }
        const value={organizationId:actor.org,baseId:d.baseId,name:d.name.trim(),active:d.active,
          enabledServices:d.enabledServices,contactName:d.contactName.trim(),contactPhone:d.contactPhone.trim(),
          revision:d.expectedRevision+1,updatedBy:request.auth.uid,updatedAt:timestamp(),
          ...(before ? {} : {createdBy:request.auth.uid,createdAt:timestamp()})};
        for (const row of [...roster,...gear]) tx.delete(row.ref);
        for (const uid of d.memberIds) tx.set(db.doc(`unitRoster/${linkKey(d.id,uid)}`),{organizationId:actor.org,unitId:d.id,userId:uid,active:true});
        for (const equipmentId of d.vesselIds) tx.set(db.doc(`unitEquipment/${linkKey(d.id,equipmentId)}`),{organizationId:actor.org,unitId:d.id,equipmentId});
        tx.set(ref,value,{merge:true});
        changed(tx,actor,request,'responseUnit.saved',d.id,before,{...value,memberIds:d.memberIds,vesselIds:d.vesselIds});
        return {saved:true,id:d.id,revision:value.revision};
      });
    },
    setUnitAllocation: async request => {
      const d=request.data || {};
      validate(d,['memberIds','vesselIds','validUntilMs']);
      if (!ids(d.memberIds,50) || !ids(d.vesselIds,10)) fail('Kontrolli ressursside valikut.');
      const releasing=d.memberIds.length+d.vesselIds.length===0;
      if (!releasing && (!Number.isSafeInteger(d.validUntilMs) || d.validUntilMs<=now() || d.validUntilMs>now()+24*60*60*1000)) fail('Vali jaotuse lõpp järgmise 24 tunni jooksul.');
      return db.runTransaction(async tx=>{
        const actor=await access(txDb(tx),request,{adminOnly:true});
        const {ref,before}=await own(tx,`responseUnits/${d.id}`,actor.org,d.expectedRevision);
        if (!before || (!releasing && before.active!==true)) fail('Aktiivset üksust ei leitud.');
        const roster=await query(tx,'unitRoster','unitId',d.id,50);
        const gear=await query(tx,'unitEquipment','unitId',d.id,10);
        if (d.memberIds.some(uid=>!roster.some(r=>r.data().userId===uid)) || d.vesselIds.some(eid=>!gear.some(r=>r.data().equipmentId===eid))) fail('Ressurss peab kuuluma üksuse võimalikku koosseisu.');
        const selected=await resources(tx,actor.org,d.memberIds,d.vesselIds);
        const previous=await query(tx,'resourceAllocations','unitId',d.id,60);
        const at=now();
        if (!releasing && d.validUntilMs<=at) fail('Jaotuse lõppaeg on möödunud. Vali uus aeg.');
        for (const resource of selected) {
          const old=(await tx.get(db.doc(`resourceAllocations/${resource.key}`))).data();
          if (old && old.unitId!==d.id && require('./center-resources').allocationActive(old,at)) throw new HttpsError('failed-precondition','Valitud liige või alus on juba teisele üksusele määratud. Vabasta senine jaotus või oota selle lõppu.');
        }
        for (const old of previous) tx.delete(old.ref);
        for (const r of selected) tx.set(db.doc(`resourceAllocations/${r.key}`),{
          organizationId:actor.org,unitId:d.id,kind:r.kind,resourceId:r.resourceId,
          identityVerified:r.identityVerified,...(r.kind==='vessel'?{physicalResourceId:r.physicalResourceId}:{}),
          validUntil:fromMillis(d.validUntilMs),updatedBy:request.auth.uid,updatedAt:timestamp()});
        tx.update(ref,{revision:d.expectedRevision+1,updatedAt:timestamp(),updatedBy:request.auth.uid});
        changed(tx,actor,request,'responseUnit.allocation',d.id,
          {resources:previous.map(p=>({kind:p.data().kind,resourceId:p.data().resourceId,validUntil:p.data().validUntil}))},
          {memberIds:d.memberIds,vesselIds:d.vesselIds,validUntil:releasing?null:fromMillis(d.validUntilMs)});
        return {saved:true,revision:d.expectedRevision+1};
      });
    },
  };
}
module.exports={createResponseUnitHandlers,coordinates,key};
