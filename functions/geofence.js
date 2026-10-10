const {randomUUID} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {access,organizationDocs} = require('./statistics-handlers');
const {orgId,millis} = require('./statistics-history');
const {unavailableMembers} = require('./effective-readiness');
const {FRESH_MS,SAMPLE_MS,managed,availabilityStatus,validateSettings,transition} = require('./geofence-policy');
const fail = message => { throw new HttpsError('failed-precondition',message); };

function createGeofence({db,now=Date.now}) {
  const transactional = tx => require('./organization-center-readiness').transactionalDb(db,tx);
  async function config(reader, actor) {
    const settings = (await reader.doc(`organizationGeofenceSettings/${actor.org}`).get()).data() ||
      {enabled:false,innerMeters:3000,outerMeters:8000,delayMinutes:15,revision:0};
    let base;
    if (actor.organization.primaryRescueBaseId) {
      base = (await reader.doc(`rescueBases/${actor.organization.primaryRescueBaseId}`).get()).data();
    } else {
      const rows = await reader.collection('rescueBases').where('organizationId','==',actor.org).limit(2).get();
      if (rows.size === 1) base = rows.docs[0].data();
    }
    const located = base?.organizationId === actor.org && base.positionVerifiedAt &&
      Number.isFinite(base.position?.latitude) && Number.isFinite(base.position?.longitude);
    return {...settings,latitude:located ? base.position.latitude : null,longitude:located ? base.position.longitude : null,
      version:`${settings.revision}:${located ? `${base.position.latitude}:${base.position.longitude}` : 'missing'}`};
  }
  async function participating(reader, org, uid) {
    const callouts = await organizationDocs(reader,'callouts',org);
    for (const c of callouts.filter(c=>c.data().status === 'active')) {
      const response = (await reader.doc(`calloutResponses/${c.id}_${uid}`).get()).data();
      if (orgId(response) === org && ['responding','delayed'].includes(response?.response)) return true;
      const attendance = (await reader.doc(`calloutAttendance/${c.id}_${uid}`).get()).data();
      if (attendance?.organizationId === org && attendance.status === 'confirmed') return true;
    }
    return false;
  }
  async function plannedAbsence(reader, org, uid, at) {
    const periods=await organizationDocs(reader,'plannedUnavailability',org);
    const rules=await organizationDocs(reader,'plannedUnavailabilityRules',org);
    return unavailableMembers(periods.map(p=>p.data()),rules.map(r=>r.data()),at).includes(uid);
  }
  function saveAvailability(tx, ref, a, uid, org, status, minutes, at, auto) {
    tx.set(ref,{id:ref.id,userId:uid,organizationId:org,commandId:org,status,
      responseMinutes:status === 'delayed' ? minutes : null,updatedAt:new Date(at),
      ...(!a ? {createdAt:new Date(at),note:null} : {}),
      geofenceAppliedAt:auto ? new Date(at) : null,geofenceUntil:auto ? new Date(at+FRESH_MS) : null}, {merge:true});
  }
  async function handle(request) {
    const d=request.data || {}, action=d.action;
    const allowed={get:[],save:['enabled','innerMeters','outerMeters','delayMinutes','expectedRevision'],
      enable:[],disable:['sessionId'],event:['sessionId','zone','observedAtMs','returnCandidate'],confirm:['sessionId','observedAtMs']};
    if (!Object.hasOwn(allowed,action) || Object.keys(d).some(k=>!['action','organizationId',...allowed[action]].includes(k))) {
      throw new HttpsError('invalid-argument','Kontrolli piirkonnaandmeid. Isiklikke koordinaate ei saadeta.');
    }
    if (Object.hasOwn(d,'returnCandidate') && (typeof d.returnCandidate!=='boolean' || d.zone!=='unknown')) {
      throw new HttpsError('invalid-argument','Naasmise vihje on lubatud ainult täpsustamata asukoha korral.');
    }
    return db.runTransaction(async tx => {
      const reader=transactional(tx), actor=await access(reader,request,{adminOnly:action==='save'});
      const uid=request.auth.uid, org=actor.org, at=now();
      const cfg=await config(reader,actor);
      const ref=db.doc(`geofenceStates/${uid}_${org}`), state=(await tx.get(ref)).data();
      const aRef=db.doc(`availability/${uid}_${org}`), a=(await tx.get(aRef)).data();
      const wasManual=state?.enabled && (!managed(a) || millis(a?.updatedAt)!==state.availabilityAtMs);
      if (action==='get') {
        const absent=await plannedAbsence(reader,org,uid,at);
        return {config:cfg,state:state ? {...state,...(wasManual ? {enabled:false,reason:'manual'} :
          state.enabled && state.expiresAtMs<=at ? {enabled:false,reason:'stale'} :
            state.enabled && absent ? {reason:'plannedAbsence',confirmationRequired:false} : {})} : null};
      }
      if (action==='save') {
        if (!validateSettings(d) || d.expectedRevision!==cfg.revision) throw new HttpsError('invalid-argument','Kontrolli raadiusi või laadi seaded uuesti.');
        if(d.enabled && cfg.latitude==null) fail('Määra ja kinnita kõigepealt ühingu asukoht keskuste kaardi seadetes.');
        const value={organizationId:org,enabled:d.enabled,innerMeters:d.innerMeters,outerMeters:d.outerMeters,
          delayMinutes:d.delayMinutes,revision:cfg.revision+1,updatedAt:new Date(at),updatedBy:uid};
        tx.set(db.doc(`organizationGeofenceSettings/${org}`),value);
        tx.create(db.doc(`platformAudit/${randomUUID()}`),{organizationId:org,action:'organization.geofence',
          targetId:org,before:{enabled:cfg.enabled,innerMeters:cfg.innerMeters,outerMeters:cfg.outerMeters,delayMinutes:cfg.delayMinutes},
          after:value,createdBy:uid,createdAt:new Date(at)});
        return {saved:true};
      }
      if(action==='disable') {
        if(d.sessionId != null && state?.sessionId!==d.sessionId) return {ignored:true};
        if (state) tx.update(ref,{enabled:false,reason:'disabled',confirmationRequired:false,updatedAt:new Date(at)});
        // Explicitly stopping automatic duty must not overwrite a later
        // manual choice, nor leave automatic duty active without monitoring.
        if(state?.enabled && !wasManual) saveAvailability(tx,aRef,a,uid,org,'offDuty',null,at,false);
        return {saved:true};
      }
      if (!cfg.enabled || cfg.latitude==null) fail('Ühingu asukohapõhine valmisolek ei ole seadistatud.');
      if (action==='enable') {
        if(await plannedAbsence(reader,org,uid,at)) fail('Planeeritud mittevalve on aktiivne. Automaatika saad sisse lülitada pärast selle lõppu ja valvesse märkimist.');
        if(availabilityStatus(a,at)!=='onDuty') fail('Märgi end kõigepealt valvesse. Asukohaautomaatika kohandab ainult sinu alustatud valvet.');
        if(await participating(reader,org,uid)) fail('Osaled aktiivsel väljakutsel. Lülita automaatika sisse pärast väljakutset.');
        const value={organizationId:org,userId:uid,sessionId:randomUUID(),version:cfg.version,enabled:true,
          zone:'unknown',reason:'waiting',confirmedInner:false,confirmationRequired:false,lastObservedMs:0,
          availabilityAtMs:at,expiresAtMs:at+FRESH_MS,updatedAt:new Date(at)};
        tx.set(ref,value);
        saveAvailability(tx,aRef,a,uid,org,'onDuty',null,at,true);
        return {config:cfg,state:value};
      }
      if (!state?.enabled || state.sessionId!==d.sessionId) fail('Automaatika on peatatud või teises telefonis uuesti sisse lülitatud.');
      if (state.expiresAtMs<=at) fail('Asukohakinnitus on aegunud. Lülita automaatika uuesti sisse.');
      if (wasManual || state.version!==cfg.version) {
        tx.update(ref,{enabled:false,reason:wasManual?'manual':'configuration',confirmationRequired:false,updatedAt:new Date(at)});
        if(!wasManual) saveAvailability(tx,aRef,a,uid,org,'offDuty',null,at,false);
        return {stopped:true};
      }
      if (!Number.isSafeInteger(d.observedAtMs) || d.observedAtMs>at+30000 || d.observedAtMs<at-SAMPLE_MS) fail('Asukoha kinnitus on aegunud. Kontrolli asukohta uuesti.');
      if (await participating(reader,org,uid)) {
        tx.update(ref,{enabled:false,reason:'callout',confirmationRequired:false,updatedAt:new Date(at)});
        saveAvailability(tx,aRef,a,uid,org,a.status,a.responseMinutes,at,false);
        return {stopped:true};
      }
      const absent=await plannedAbsence(reader,org,uid,at);
      if(absent) {
        if(action==='confirm') fail('Planeeritud mittevalve on aktiivne. Selle ajal ei saa asukoha alusel valvesse märkida.');
        if (!['inner','ring','outside','unknown'].includes(d.zone)) throw new HttpsError('invalid-argument','Tundmatu piirkond.');
        if(d.observedAtMs<=state.lastObservedMs) return {ignored:true};
        // Do not touch availability or renew its lease during an absence.
        // A later fresh event will apply the location after the plan ends.
        tx.update(ref,{lastObservedMs:d.observedAtMs,reason:'plannedAbsence',confirmationRequired:false,updatedAt:new Date(at)});
        return {saved:true,paused:true};
      }
      if(action==='confirm') {
        if(state.zone!=='inner' || state.lastObservedMs!==d.observedAtMs || !state.confirmationRequired) fail('Kontrolli kõigepealt, et asud valvesoleku raadiuses.');
        tx.update(ref,{confirmedInner:true,confirmationRequired:false,reason:'confirmed',availabilityAtMs:at,expiresAtMs:at+FRESH_MS,updatedAt:new Date(at)});
        saveAvailability(tx,aRef,a,uid,org,'onDuty',null,at,true);
        return {saved:true};
      }
      if (!['inner','ring','outside','unknown'].includes(d.zone)) throw new HttpsError('invalid-argument','Tundmatu piirkond.');
      if(d.observedAtMs<=state.lastObservedMs) return {ignored:true};
      const next=transition(state,d.zone,a.status,cfg.delayMinutes);
      // Native boundary entry may precede a usable GPS fix. It can only
      // request confirmation; unknown location remains off-duty. Confirm
      // still requires a fresh, accurate inner-region sample above.
      if(d.returnCandidate===true) next.confirmationRequired=true;
      const reason=d.returnCandidate===true?'returnCandidate':d.zone==='unknown'?'locationUnavailable':'observed';
      tx.update(ref,{zone:d.zone,lastObservedMs:d.observedAtMs,confirmedInner:next.confirmedInner,
        confirmationRequired:next.confirmationRequired,reason,
        ...(a.status!==next.status ? {statusChange:{atMs:at,from:a.status,to:next.status,
          zone:d.zone,responseMinutes:next.responseMinutes}} : {}),
        availabilityAtMs:at,expiresAtMs:at+FRESH_MS,updatedAt:new Date(at)});
      saveAvailability(tx,aRef,a,uid,org,next.status,next.responseMinutes,at,true);
      return {saved:true,confirmationRequired:next.confirmationRequired};
    });
  }
  async function expire() {
    const states=await db.collection('geofenceStates').where('enabled','==',true).get();
    for(const doc of states.docs) await db.runTransaction(async tx=>{
      const state=(await tx.get(doc.ref)).data();
      if(!state?.enabled) return;
      const reader=transactional(tx), at=now(), org=state.organizationId, uid=state.userId;
      const aRef=db.doc(`availability/${uid}_${org}`), a=(await tx.get(aRef)).data();
      const manual=!managed(a) || millis(a?.updatedAt)!==state.availabilityAtMs;
      let reason=manual?'manual':state.expiresAtMs<=at?'stale':null;
      try {
        const actor=await access(reader,{auth:{uid},data:{organizationId:org}});
        const cfg=await config(reader,actor);
        if(!cfg.enabled || cfg.version!==state.version) reason='configuration';
      } catch(error) { if(error.code==='permission-denied') reason='membership'; else throw error; }
      if(!reason) return;
      const inCallout=!manual && await participating(reader,org,uid);
      tx.update(doc.ref,{enabled:false,reason:inCallout?'callout':reason,confirmationRequired:false,updatedAt:new Date(at)});
      if(!manual) saveAvailability(tx,aRef,a,uid,org,inCallout?a.status:'offDuty',inCallout?a.responseMinutes:null,at,false);
    });
  }
  return {handle,expire};
}
module.exports={createGeofence};
