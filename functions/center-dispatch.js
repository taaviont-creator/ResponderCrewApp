const {createHash} = require('node:crypto');
const {HttpsError} = require('firebase-functions/v2/https');
const {CENTERS, allowed} = require('./center-access');
const {access} = require('./statistics-handlers');
const id = v => typeof v === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(v);
const hash = (...v) => createHash('sha256').update(JSON.stringify(v)).digest('hex');
const fail = message => { throw new HttpsError('invalid-argument', message); };
const text = (v, max = 6000) => typeof v === 'string' && v.length <= max;
function validateDetails(d) {
  if (!text(d.title, 200) || !d.title.trim() || !text(d.description) || !d.description.trim() ||
      !text(d.location, 1000) || !text(d.radioChannel ?? '',200) || !text(d.otherResponders ?? '',2000) || !['unknown','approximate','lastKnown','exact'].includes(d.positionKind)) fail('Lisa pealkiri ja teadaolev info. Asukoht võib jääda täpsustamisel.');
  const p = d.position;
  if (p !== null && (!p || !Number.isFinite(p.latitude) || Math.abs(p.latitude) > 90 ||
      !Number.isFinite(p.longitude) || Math.abs(p.longitude) > 180 || Object.keys(p).some(k => !['latitude','longitude'].includes(k)))) fail('Kontrolli koordinaate.');
  if ((d.positionKind === 'unknown') !== (p === null)) fail('Vali koordinaatidele asukoha täpsus.');
  return {title:d.title.trim(),description:d.description.trim(),location:d.location.trim(),radioChannel:(d.radioChannel ?? '').trim(),otherResponders:(d.otherResponders ?? '').trim(),position:p,positionKind:d.positionKind};
}
function validateTargets(targets) {
  if (!Array.isArray(targets) || !targets.length || targets.length > 30 ||
      new Set(targets.map(t => t?.organizationId)).size !== targets.length ||
      targets.some(t => !t || !id(t.organizationId) || Object.hasOwn(t,'task') || (t.existingCalloutId != null && !id(t.existingCalloutId)))) fail('Vali 1–30 erinevat ühingut.');
}
// Shared incident is authoritative. Existing organization callouts are server-
// maintained projections for legacy apps, reports and realtime subscriptions.
// Their log/crew/report documents remain entirely organization-owned.
function createCenterDispatch({db,timestamp,now=Date.now}) {
  const readDb = tx => ({doc:path => ({get:() => tx.get(db.doc(path))})});
  async function center(tx,request) {
    const centerId=request.data.centerId, definition=CENTERS[centerId];
    if (!Object.hasOwn(CENTERS,centerId)) fail('Tundmatu keskus.');
    const [c,g]=await tx.getAll(db.doc(`centers/${centerId}`),db.doc(`centerAccess/${request.auth.uid}/grants/${centerId}`));
    if (!allowed(g.data(),c.data(),definition.service,now()) || g.data().canDispatch!==true) throw new HttpsError('permission-denied','Väljakutsete saatmise õigus puudub.');
    return {id:centerId,...definition};
  }
  async function target(tx,org,c) {
    const [o,p,s]=await tx.getAll(db.doc(`commands/${org}`),db.doc(`organizationCenterPublication/${org}_${c.id}`),db.doc(`organizationResponseSettings/${org}`));
    if (o.data()?.status!=='approved' || p.data()?.organizationId!==org || p.data()?.centerId!==c.id ||
        !p.data()?.requested || !p.data()?.approved || s.data()?.services?.[c.service]?.enabled!==true) {
      throw new HttpsError('permission-denied','Ühing ei ole selle keskuse ja teenusega jagatud.');
    }
    return o.data();
  }
  function audit(tx,receipt,request,incidentId,action) {
    tx.create(db.doc(`platformAudit/${receipt}`),{action:`dispatch.${action}`,targetId:incidentId,
      organizationId:request.data.organizationId || null,
      change:{response:request.data.response || null,reason:request.data.reason || '',expectedRevision:request.data.expectedRevision ?? null},
      createdBy:request.auth.uid,createdAt:timestamp()});
  }
  function projectCallout(tx,incident,assignment,revision,message,critical=false) {
    const ref=db.doc(`callouts/${assignment.calloutId}`);
    const dispatch={incidentId:incident.id,centerId:incident.centerId,centerName:incident.centerName,
      incidentStatus:incident.status,revision,radioChannel:incident.radioChannel || '',otherResponders:incident.otherResponders || '',organizations:incident.organizations || [],response:assignment.response,
      responseReason:assignment.responseReason || '',acknowledgedRevision:assignment.acknowledgedRevision || 0,
      message,critical:critical || (assignment.criticalRevision || 0)>(assignment.acknowledgedRevision || 0),
      criticalRevision:assignment.criticalRevision || 0,criticalMessage:assignment.criticalMessage || '',updatedAt:timestamp(),position:incident.position,positionKind:incident.positionKind};
    tx.update(ref,{title:incident.title,description:incident.description,location:incident.location,
      dispatch,updatedAt:timestamp()});
    tx.set(ref.collection('centerUpdates').doc(String(revision)),{organizationId:assignment.organizationId,
      text:message,critical,revision,createdBy:incident.updatedBy,createdAt:timestamp(),
      incidentStatus:incident.status,radioChannel:incident.radioChannel || '',otherResponders:incident.otherResponders || '',location:incident.location,
      position:incident.position,positionKind:incident.positionKind});
    tx.create(db.doc(`dispatchUpdateEvents/${hash(incident.id,assignment.organizationId,revision)}`),{
      organizationId:assignment.organizationId,calloutId:assignment.calloutId,incidentId:incident.id,revision,critical,createdAt:timestamp()});
  }
  return {
    handle: async request => {
      if (!request.auth?.uid) throw new HttpsError('unauthenticated','Logi sisse.');
      const d=request.data || {};
      if (!id(d.requestId) || !['create','update','append','addTargets','respond','acknowledge'].includes(d.action)) fail('Kontrolli toimingut.');
      if (d.action!=='create' && !id(d.incidentId)) fail('Sündmus puudub.');
      const receipt=hash(request.auth.uid,d.action,d.requestId), receiptRef=db.doc(`dispatchRequests/${receipt}`);
      const incidentId=d.action==='create'?hash(request.auth.uid,d.centerId,d.requestId):d.incidentId;
      const ref=db.doc(`dispatchIncidents/${incidentId}`);
      const details=['create','update'].includes(d.action)?validateDetails(d):null;
      if (['create','addTargets'].includes(d.action)) validateTargets(d.targets);
      if (['update','append'].includes(d.action) && (!text(d.message,3000) || !d.message.trim() || typeof d.critical!=='boolean' ||
          (d.action==='update' && !['active','closed','cancelled'].includes(d.status)) ||
          d.targetOrganizationId != null || d.task != null)) fail('Lisa muudatuse selgitus ja kontrolli olekut.');
      if (d.action==='respond' && (!['accepted','declined'].includes(d.response) || !text(d.reason,1000) ||
          (d.response==='declined' && !d.reason.trim()))) fail('Keeldumisel lisa põhjus.');
      return db.runTransaction(async tx => {
        const crew=['respond','acknowledge'].includes(d.action);
        const actor=crew?await access(readDb(tx),request,{crewOnly:true}):await center(tx,request);
        const [previous,snapshot]=await tx.getAll(receiptRef,ref);
        if (previous.exists) {
          if (previous.data().fingerprint!==hash(d)) throw new HttpsError('already-exists','Sama päringu tunnust kasutati teise sisuga.');
          return previous.data().result;
        }
        let incident=snapshot.data();
        if (d.action!=='create' && !incident) throw new HttpsError('not-found','Sündmust ei leitud.');
        if (!crew && incident && incident.centerId!==actor.id) throw new HttpsError('permission-denied','Sündmus kuulub teisele keskusele.');
        if (crew) {
          const assignmentRef=ref.collection('assignments').doc(actor.org), assignment=(await tx.get(assignmentRef)).data();
          if (!assignment) throw new HttpsError('permission-denied','Ühing ei ole sündmusele kaasatud.');
          const calloutRef=db.doc(`callouts/${assignment.calloutId}`), callout=(await tx.get(calloutRef)).data();
          if (!callout || callout.organizationId!==actor.org || callout.dispatch?.incidentId!==incidentId) throw new HttpsError('failed-precondition','Väljakutse seos puudub.');
          if (assignment.revision!==d.expectedRevision) throw new HttpsError('aborted','Infot muudeti. Vaata värsket infot.');
          if (d.action==='respond' && assignment.response!==d.expectedResponse) throw new HttpsError('aborted','Teine meeskonnajuht muutis vastust. Vaata värsket infot.');
          if (d.action==='respond' && (incident.status!=='active' || callout.status!=='active')) throw new HttpsError('failed-precondition','Väljakutse ei ole enam aktiivne.');
          const change=d.action==='respond'?{response:d.response,responseReason:d.reason.trim(),respondedBy:request.auth.uid,respondedAt:timestamp()}:
            {acknowledgedRevision:assignment.revision,acknowledgedBy:request.auth.uid,acknowledgedAt:timestamp()};
          let organizations=incident.organizations || [];
          if (d.action==='respond') {
            const peers=(await tx.get(ref.collection('assignments'))).docs.map(s=>s.data());
            organizations=peers.map(a=>({organizationId:a.organizationId,name:a.organizationName,response:a.organizationId===actor.org?d.response:a.response}));
            tx.update(ref,{organizations});
            for(const a of peers) if(a.organizationId!==actor.org) tx.update(db.doc(`callouts/${a.calloutId}`),{'dispatch.organizations':organizations});
          }
          tx.update(assignmentRef,{...change,updatedAt:timestamp()});
          const projection={...callout.dispatch,organizations};
          if (d.action==='respond') Object.assign(projection,{response:d.response,responseReason:d.reason.trim()});
          else projection.acknowledgedRevision=assignment.revision;
          tx.update(calloutRef,{dispatch:projection,updatedAt:timestamp()});
        } else if (d.action==='create' || d.action==='addTargets') {
          if (incident && (incident.status!=='active' || incident.revision!==d.expectedRevision)) throw new HttpsError('aborted','Sündmust muudeti või see on lõpetatud.');
          const existing=incident?(await tx.get(ref.collection('assignments'))).docs.map(s=>s.data()):[];
          if (existing.length+d.targets.length>30) fail('Ühele sündmusele saab kaasata kuni 30 ühingut.');
          if (d.targets.some(t=>existing.some(a=>a.organizationId===t.organizationId))) throw new HttpsError('already-exists','Ühing on juba kaasatud.');
          const organizations=[],existingCallouts=[];
          for (const t of d.targets) {
            organizations.push(await target(tx,t.organizationId,actor));
            const old=t.existingCalloutId?(await tx.get(db.doc(`callouts/${t.existingCalloutId}`))).data():null;
            if (t.existingCalloutId && (!old || old.organizationId!==t.organizationId || old.dispatch || old.status!=='active' ||
                old.phoneCenterId!==actor.id || old.calloutType!==actor.service || (old.isTest===true)!==(incident?.isTest ?? (d.isTest===true)))) {
              throw new HttpsError('failed-precondition','Sidumiseks peab olema selle keskuse telefonikõne põhjal loodud aktiivne sama tüübi väljakutse.');
            }
            existingCallouts.push(old);
          }
          const at=timestamp();
          const participating=[...existing.map(a=>({organizationId:a.organizationId,name:a.organizationName,response:a.response})),
            ...d.targets.map((t,i)=>({organizationId:t.organizationId,name:organizations[i].name || 'Ühing',response:'pending'}))];
          if (!incident) {
            incident={id:incidentId,centerId:actor.id,centerName:actor.name,service:actor.service,...details,organizations:participating,
              status:'active',revision:1,isTest:d.isTest===true,createdBy:request.auth.uid,updatedBy:request.auth.uid,createdAt:at,updatedAt:at};
            tx.create(ref,incident);
          } else {
            incident={...incident,revision:incident.revision+1,organizations:participating};
            tx.update(ref,{revision:incident.revision,organizations:participating,updatedAt:at,updatedBy:request.auth.uid});
            for(const a of existing) tx.update(db.doc(`callouts/${a.calloutId}`),{'dispatch.organizations':participating});
          }
          for (let i=0;i<d.targets.length;i++) {
            const t=d.targets[i], org=t.organizationId, calloutId=t.existingCalloutId || hash(incidentId,org), logId=`callout_${calloutId}_created`;
            const assignment={organizationId:org,organizationName:organizations[i].name || 'Ühing',calloutId,
              response:'pending',responseReason:'',revision:incident.revision,acknowledgedRevision:0,
              createdAt:at,updatedAt:at,progress:'open'};
            tx.create(ref.collection('assignments').doc(org),assignment);
            const calloutProjection={id:calloutId,organizationId:org,commandId:org,
              title:incident.title,description:incident.description,location:incident.location,status:'active',priority:'high',
              calloutType:actor.service,responseTargetMinutes:actor.service==='tross'?60:null,isTest:incident.isTest,
              createdBy:request.auth.uid,createdByName:actor.name,createdAt:at,updatedAt:at,closedAt:null,
              dispatch:{incidentId,centerId:actor.id,centerName:actor.name,incidentStatus:'active',revision:incident.revision,
                radioChannel:incident.radioChannel || '',otherResponders:incident.otherResponders || '',organizations:participating,response:'pending',responseReason:'',acknowledgedRevision:0,message:'Keskus edastas väljakutse.',
                critical:false,updatedAt:at,position:incident.position,positionKind:incident.positionKind}};
            if (existingCallouts[i]) {
              const old=existingCallouts[i];
              tx.update(db.doc(`callouts/${calloutId}`),{dispatch:calloutProjection.dispatch,title:incident.title,description:incident.description,location:incident.location,updatedAt:at});
              tx.create(db.doc(`callouts/${calloutId}/changeHistory/${receipt}`),{organizationId:org,before:{title:old.title,description:old.description,location:old.location},after:{incidentId,title:incident.title,description:incident.description,location:incident.location},createdBy:request.auth.uid,createdAt:at});
              tx.create(db.doc(`dispatchUpdateEvents/${hash(incidentId,org,'linked')}`),{organizationId:org,calloutId,incidentId,revision:incident.revision,critical:false,createdAt:at});
            } else tx.create(db.doc(`callouts/${calloutId}`),calloutProjection);
            tx.create(db.doc(`notifications/dispatch_${calloutId}`),{id:`dispatch_${calloutId}`,organizationId:org,commandId:org,
              title:'Keskuse väljakutse',message:'Ava väljakutse ja tutvu infoga.',type:'callout',priority:'high',
              relatedType:'callout',relatedId:calloutId,createdBy:request.auth.uid,createdAt:at,updatedAt:at});
            if (!existingCallouts[i]) {
            tx.create(db.doc(`operationLogs/${logId}`),{id:logId,organizationId:org,commandId:org,calloutId,
              createdBy:request.auth.uid,createdByName:actor.name,type:'note',title:`Väljakutse: ${incident.title}`,
              description:incident.description,status:'open',timestamp:at,createdAt:at,updatedAt:at});
            tx.create(db.doc(`operationLogs/${logId}/events/created`),{id:'created',organizationId:org,commandId:org,operationLogId:logId,
              type:'statusChange',status:'open',title:'Keskuse väljakutse vastu võetud rakendusse',description:'',
              createdBy:request.auth.uid,createdByName:actor.name,createdAt:at});
            }
          }
        } else {
          if (incident.revision!==d.expectedRevision) throw new HttpsError('aborted','Teine töötaja muutis sündmust. Laadi uus versioon.');
          if (incident.status!=='active' && d.status==='active') throw new HttpsError('failed-precondition','Lõpetatud sündmust ei saa uuesti alarmeerida.');
          const assignments=(await tx.get(ref.collection('assignments'))).docs.map(s=>s.data());
          const shared=d.action==='append'?validateDetails(incident):details;
          const status=d.action==='append'?incident.status:d.status;
          const revision=incident.revision+1;
          incident={...incident,...shared,status,revision,updatedBy:request.auth.uid,updatedAt:timestamp()};
          tx.set(ref,incident);
          tx.create(ref.collection('updates').doc(String(revision)),{...shared,message:d.message.trim(),critical:d.critical,
            status,createdBy:request.auth.uid,createdAt:timestamp()});
          for (let a of assignments) {
            if(d.critical || d.status==='cancelled') a={...a,criticalRevision:revision,criticalMessage:d.message.trim()};
            tx.update(ref.collection('assignments').doc(a.organizationId),{revision,criticalRevision:a.criticalRevision || 0,criticalMessage:a.criticalMessage || '',updatedAt:timestamp()});
            projectCallout(tx,incident,a,revision,d.message.trim(),d.critical || d.status==='cancelled');
          }
        }
        const result={saved:true,incidentId};
        audit(tx,receipt,request,incidentId,d.action);
        tx.create(receiptRef,{fingerprint:hash(d),result,createdAt:timestamp()});
        return result;
      });
    },
    // Fetch current state inside a transaction so late/repeated triggers cannot
    // roll a center's progress back. Never publish log text or crew identities.
    syncProgress: async event => {
      const data=event.data?.after?.data() || event.data?.before?.data();
      const parent=event.params.eventId && event.params.logId ? (await db.doc(`operationLogs/${event.params.logId}`).get()).data() : null;
      const calloutId=data?.calloutId || parent?.calloutId || (event.params.calloutId ?? null);
      if (!id(calloutId)) return;
      await db.runTransaction(async tx => {
        const callout=(await tx.get(db.doc(`callouts/${calloutId}`))).data();
        if (!callout?.dispatch?.incidentId) return;
        const ref=db.doc(`dispatchIncidents/${callout.dispatch.incidentId}/assignments/${callout.organizationId}`);
        const [assignment,log,delivery,responses,returnEvents]=await Promise.all([tx.get(ref),tx.get(db.doc(`operationLogs/callout_${calloutId}_created`)),
          tx.get(db.doc(`calloutPushDeliveries/${calloutId}`)),tx.get(db.collection('calloutResponses').where('calloutId','==',calloutId)),
          tx.get(db.collection(`operationLogs/callout_${calloutId}_created/events`).where('title','==','Tagasisõit'))]);
        if (!assignment.exists || assignment.data().calloutId!==calloutId) return;
        const counts={responding:0,delayed:0,unavailable:0};
        for (const r of responses.docs) if (r.data().organizationId===callout.organizationId && Object.hasOwn(counts,r.data().response)) counts[r.data().response]++;
        const returning=log.data()?.status==='completed' && returnEvents.docs.some(e=>e.data().type==='quickAction' && e.data().createdAt?.toMillis() >= (log.data().updatedAt?.toMillis() || 0));
        tx.update(ref,{progress:returning?'returning':log.data()?.status || 'open',calloutStatus:callout.status,responseCounts:counts,
          pushStatus:delivery.data()?.status || 'unconfirmed',progressAt:log.data()?.updatedAt || null,updatedAt:timestamp()});
      });
    },
  };
}
module.exports={createCenterDispatch,validateDetails,validateTargets};
