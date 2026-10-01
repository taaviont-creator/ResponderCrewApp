const {randomUUID}=require('node:crypto');
const {HttpsError}=require('firebase-functions/v2/https');
const {access}=require('./statistics-handlers');
const {orgId}=require('./statistics-history');

const SERVICES=['sar','tross'];
const id=v=>typeof v==='string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const record=v=>v && typeof v==='object' && !Array.isArray(v);
const only=(v,keys)=>record(v) && Object.keys(v).every(k=>keys.includes(k));
const vessel=e=>e && e.category==='vessel' && (e.scope==='organization' || e.scope==null) && !e.ownerUserId && !e.assignedToUserId;
const invalid=message=>{throw new HttpsError('invalid-argument',message);};

function validateSettings(data) {
  if (!only(data,['organizationId','expectedRevision','services','contactName','contactPhone']) ||
      !Number.isSafeInteger(data.expectedRevision) || data.expectedRevision<0 ||
      !only(data.services,SERVICES) || SERVICES.some(s=>!record(data.services[s])) ||
      typeof data.contactName!=='string' || data.contactName.length>120 ||
      typeof data.contactPhone!=='string' || data.contactPhone.length>60) invalid('Kontrolli teenuste seadistust.');
  const services={};
  for (const name of SERVICES) {
    const s=data.services[name];
    if (!only(s,['enabled','departureMinutes','vesselIds',...(name==='tross'?['minimumResponders']:[])]) ||
        typeof s.enabled!=='boolean' || !Array.isArray(s.vesselIds) || s.vesselIds.length>10 ||
        s.vesselIds.some(v=>!id(v)) || new Set(s.vesselIds).size!==s.vesselIds.length ||
        (s.enabled && s.vesselIds.length===0) ||
        (s.departureMinutes!==null && (!Number.isInteger(s.departureMinutes) || s.departureMinutes<1 || s.departureMinutes>60)) ||
        (s.enabled && s.departureMinutes===null) ||
        (name==='tross' && (!Number.isInteger(s.minimumResponders) || s.minimumResponders<1 || s.minimumResponders>50))) {
      invalid(`Kontrolli ${name==='sar'?'SAR-i':'Trossi'} väljasõiduaega ja aluste valikut.`);
    }
    services[name]={enabled:s.enabled,departureMinutes:s.departureMinutes,vesselIds:[...s.vesselIds].sort(),
      ...(name==='tross'?{minimumResponders:s.minimumResponders}:{})};
  }
  return {services,contactName:data.contactName.trim(),contactPhone:data.contactPhone.trim()};
}

function defaults(data) {
  return {revision:data?.revision ?? 0,contactName:data?.contactName ?? '',contactPhone:data?.contactPhone ?? '',
    services:Object.fromEntries(SERVICES.map(name=>[name,{
      enabled:data?.services?.[name]?.enabled===true,
      departureMinutes:data?.services?.[name]?.departureMinutes ?? null,
      vesselIds:Array.isArray(data?.services?.[name]?.vesselIds)?data.services[name].vesselIds:[],
      ...(name==='tross'?{minimumResponders:data?.services?.tross?.minimumResponders ?? 1}:{}),
    }]))};
}

function createOrganizationResponseSettingsHandlers({db,timestamp}) {
  const txDb=tx=>({doc:path=>({get:()=>tx.get(db.doc(path))})});
  async function vessels(tx,org) {
    const result=new Map();
    for(const field of ['organizationId','commandId']) {
      const rows=await tx.get(db.collection('equipment').where(field,'==',org).limit(301));
      if(rows.size>300) throw new HttpsError('resource-exhausted','Varustuse loend vajab lehekülgedega laadimist.');
      for(const row of rows.docs) if(orgId(row.data())===org && vessel(row.data())) result.set(row.id,row.data());
    }
    return result;
  }
  return {
    getOrganizationResponseSettings: request=>db.runTransaction(async tx=>{
      const actor=await access(txDb(tx),request,{adminOnly:true});
      const config=(await tx.get(db.doc(`organizationResponseSettings/${actor.org}`))).data();
      const sar=(await tx.get(db.doc(`organizationReadinessSummaries/${actor.org}`))).data();
      const rows=await vessels(tx,actor.org);
      return {...defaults(config),sarMinimumCrew:Number.isInteger(sar?.minimumCrewRequired)?sar.minimumCrewRequired:null,
        vessels:[...rows].map(([id,e])=>({id,name:e.name || 'Alus',status:['ok','needsMaintenance','broken','outOfService'].includes(e.status)?e.status:'unknown'}))};
    }),
    saveOrganizationResponseSettings: async request=>{
      const data=request.data || {}, value=validateSettings(data);
      return db.runTransaction(async tx=>{
        const actor=await access(txDb(tx),request,{adminOnly:true});
        const ref=db.doc(`organizationResponseSettings/${actor.org}`), before=(await tx.get(ref)).data();
        if((before?.revision ?? 0)!==data.expectedRevision) throw new HttpsError('aborted','Seadeid on vahepeal muudetud. Laadi vaade uuesti.');
        for(const vesselId of new Set(SERVICES.flatMap(s=>value.services[s].vesselIds))) {
          const e=(await tx.get(db.doc(`equipment/${vesselId}`))).data();
          if(orgId(e)!==actor.org || !vessel(e)) invalid('Vali ainult selle ühingu ühiskasutuses olevad alused. Eemalda aegunud valik.');
        }
        // Configuration is not a readiness confirmation, publication, or resource reservation.
        const after={...value,schemaVersion:1,revision:data.expectedRevision+1,
          updatedBy:request.auth.uid,updatedAt:timestamp(),...(before?{}:{createdBy:request.auth.uid,createdAt:timestamp()})};
        tx.set(ref,after);
        tx.create(db.doc(`platformAudit/${randomUUID()}`),{action:'organization.responseSettings',organizationId:actor.org,
          targetId:actor.org,before:before?defaults(before):null,after:defaults(after),createdBy:request.auth.uid,createdAt:timestamp()});
        return {saved:true,revision:after.revision};
      });
    },
  };
}
module.exports={createOrganizationResponseSettingsHandlers,validateSettings,defaults};
