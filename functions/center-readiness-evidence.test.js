const {test}=require('node:test');
const assert=require('node:assert/strict');
const {inspectCenterEvidence,createEvidenceReader}=require('./center-readiness-evidence');
const {key}=require('./response-units');

function input() {
  const docs={},rows={},states={};
  const reader={doc:async path=>docs[path],query:async(c,f,v)=>rows[`${c}/${f}/${v}`] || [],
    readiness:async(org,at)=>states[`${org}/${at}`] || {paused:false,crew:[]}};
  const args={reader,org:'own',now:100,departureAt:200,
    readiness:{crew:[{userId:'member',level:'level2',status:'onDuty'}]},vesselEntries:[{id:'boat'}]};
  docs['vesselIdentities/boat']={organizationId:'own',verified:true,physicalResourceId:'physical'};
  return {args,docs,rows,states};
}
test('single organization needs no manual allocation and no certificate lookup for administrator-assigned II level',async()=>{
  const {args}=input();
  args.reader.query=async collection=>{assert.notEqual(collection,'certificates');return [];};
  const result=await inspectCenterEvidence(args);
  assert.deepEqual(result.reasons,[]);
  assert.ok(Object.values(result.counts).every(v=>v===0));
});
test('same member in another organization and legacy member allocations do not subtract own duty',async()=>{
  const {args,docs}=input();
  docs[`resourceAllocations/${key('member','member')}`]={organizationId:'other',validityMode:'untilChanged',validUntil:null};
  args.reader.query=async c=>{assert.notEqual(c,'memberships');return [];};
  args.reader.readiness=async()=>{throw Error('Foreign membership must not be read');};
  const result=await inspectCenterEvidence(args);
  assert.deepEqual(result.eligibleMemberIds,['member']);
  assert.equal(result.reasons.length,0);
});
test('vessel allocation still expires at the exact boundary',async()=>{
  const {args,docs}=input();
  docs[`resourceAllocations/${key('vessel','physical')}`]={organizationId:'other',validUntil:{toMillis:()=>150}};
  const result=await inspectCenterEvidence(args);
  assert.equal(result.counts.vesselReservedElsewhere,1);
  assert.equal(result.nextReviewAtMs,150);
  args.now=150;
  assert.equal((await inspectCenterEvidence(args)).counts.vesselReservedElsewhere,0);
});
test('unverified, foreign and duplicate vessel identity never silently pass as independent boats',async()=>{
  const {args,docs}=input();
  docs['vesselIdentities/boat'].organizationId='other';
  assert.equal((await inspectCenterEvidence(args)).counts.vesselUnverified,1);
  docs['vesselIdentities/boat'].organizationId='own';
  args.vesselEntries.push({id:'duplicate'});
  docs['vesselIdentities/duplicate']=docs['vesselIdentities/boat'];
  assert.equal((await inspectCenterEvidence(args)).counts.duplicateVessel,1);
});
test('one physical vessel selected by two organizations is detected across SAR/Tross but not for broken/private equipment',async()=>{
  const {args,docs,rows}=input();
  rows['vesselIdentities/physicalResourceId/physical']=[{id:'otherboat',organizationId:'other',verified:true}];
  docs['commands/other']={status:'approved',name:'PRIVATE ORG'};
  docs['equipment/otherboat']={organizationId:'other',category:'vessel',status:'ok'};
  docs['organizationResponseSettings/other']={services:{tross:{enabled:true,vesselIds:['otherboat']}}};
  let result=await inspectCenterEvidence(args);
  assert.equal(result.counts.vesselOverlap,1);
  assert.ok(!JSON.stringify(result).includes('PRIVATE'));
  docs['equipment/otherboat'].status='broken';
  assert.equal((await inspectCenterEvidence(args)).counts.vesselOverlap,0);
  docs['equipment/otherboat'].status='ok';docs['equipment/otherboat'].assignedToUserId='someone';
  assert.equal((await inspectCenterEvidence(args)).counts.vesselOverlap,0);
});
test('evidence reader caches only within its request and refuses truncated query results',async()=>{
  let reads=0;
  const db={doc:()=>({get:async()=>{reads++;return {data:()=>({value:reads})};}}),
    collection:()=>({where:()=>({limit:()=>({get:async()=>({size:21,docs:[]})})})})};
  const reader=createEvidenceReader(db);
  await reader.doc('x');await reader.doc('x');assert.equal(reads,1);
  await createEvidenceReader(db).doc('x');assert.equal(reads,2);
  await assert.rejects(reader.query('memberships','userId','u',20),{code:'resource-exhausted'});
});
