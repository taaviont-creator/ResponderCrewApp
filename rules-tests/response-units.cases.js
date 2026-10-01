const {test}=require('node:test');
const assert=require('node:assert/strict');
const {assertFails}=require('@firebase/rules-unit-testing');
const {doc,getDoc,setDoc,updateDoc,deleteDoc}=require('firebase/firestore');
module.exports=({getEnv,serverDb,serverRequire})=>{
  const org='approved-org';
  const req=(data,uid='org-admin',organizationId=org)=>({auth:{uid},data:{organizationId,...data}});
  const base=(id='base')=>({id,expectedRevision:0,name:'Päästebaas',address:'Sadam',latitude:null,longitude:null,positionVerified:false,active:true});
  const unit=(id='unit',patch={})=>({id,expectedRevision:0,name:'Üksus',baseId:'base',enabledServices:['sar','tross'],active:true,contactName:'Valvekontakt',contactPhone:'',memberIds:['active-member'],vesselIds:['boat'],...patch});
  const setup=async()=>{
    const db=serverDb(),{FieldValue,Timestamp,GeoPoint}=serverRequire('firebase-admin/firestore');
    let time=Date.parse('2026-10-01T08:00:00Z');
    const h=serverRequire('./response-units').createResponseUnitHandlers({db,timestamp:()=>FieldValue.serverTimestamp(),
      fromMillis:Timestamp.fromMillis,geoPoint:(a,b)=>new GeoPoint(a,b),now:()=>time});
    await db.doc('equipment/boat').set({organizationId:org,category:'vessel',scope:'organization',name:'Paadi nimi',status:'ok'});
    await h.saveRescueBase(req(base()));
    await h.saveResponseUnit(req(unit()));
    return {db,h,now:()=>time,advance:delta=>{time+=delta;}};
  };
  test('units: admin-only workflow and server-only collections cannot elevate center or platform roles',async()=>{
    const {db,h}=await setup();
    await db.doc('users/platform-only').set({systemRole:'platformAdmin'});
    await db.doc('centerAccess/center-only/grants/merevalvekeskus').set({active:true,services:['sar'],validUntil:null});
    for(const uid of ['active-member','outsider','platform-only','center-only']){
      await assert.rejects(h.getOrganizationUnits(req({},uid)),{code:'permission-denied'});
      await assert.rejects(h.saveRescueBase(req(base('forbidden'),uid)),{code:'permission-denied'});
      await assert.rejects(h.saveResponseUnit(req(unit('forbidden'),uid)),{code:'permission-denied'});
    }
    for(const uid of ['org-admin','active-member','platform-only','center-only']){
      const client=getEnv().authenticatedContext(uid).firestore();
      for(const path of ['rescueBases/base','responseUnits/unit','unitRoster/x','unitEquipment/x','resourceAllocations/x','vesselIdentities/boat']){
        await assertFails(getDoc(doc(client,path)));
        await assertFails(setDoc(doc(client,path),{organizationId:org,active:true,verified:true}));
        await assertFails(updateDoc(doc(client,path),{organizationId:'other-org'}));
        await assertFails(deleteDoc(doc(client,path)));
      }
    }
    const data=await h.getOrganizationUnits(req({}));
    assert.equal(data.units[0].name,'Üksus');
    assert.equal(data.bases[0].latitude,null);
    assert.equal(data.vessels[0].identityVerified,false);
  });
  test('units: foreign references, stale revisions, coordinates and archive conflicts are rejected',async()=>{
    const {db,h}=await setup();
    await db.doc('rescueBases/foreign').set({organizationId:'other-org',active:true});
    await db.doc('equipment/foreign').set({organizationId:'other-org',scope:'organization',category:'vessel'});
    await db.doc('equipment/suit').set({organizationId:org,scope:'organization',category:'safety'});
    for(const patch of [{baseId:'foreign'},{vesselIds:['foreign']},{vesselIds:['suit']},{memberIds:['outsider']},{ready:true}]){
      await assert.rejects(h.saveResponseUnit(req(unit('bad',patch))),e=>['invalid-argument','permission-denied'].includes(e.code));
    }
    await assert.rejects(h.saveRescueBase(req({...base(),latitude:59,longitude:null})),{code:'invalid-argument'});
    await assert.rejects(h.saveRescueBase(req({...base(),expectedRevision:1,active:false})),{code:'failed-precondition'});
    await assert.rejects(h.saveResponseUnit(req(unit())),{code:'aborted'});
    await h.saveRescueBase(req({...base(),expectedRevision:1,latitude:59.45,longitude:26.5,positionVerified:true}));
    const data=await h.getOrganizationUnits(req({}));
    assert.equal(data.bases[0].latitude,59.45);
    assert.equal(data.bases[0].positionVerified,true);
    const verification=(await db.doc('rescueBases/base').get()).data().positionVerifiedAt.toMillis();
    await h.saveRescueBase(req({...base(),expectedRevision:2,name:'Uus nimi',latitude:59.45,longitude:26.5,positionVerified:true}));
    assert.equal((await db.doc('rescueBases/base').get()).data().positionVerifiedAt.toMillis(),verification);
    await h.saveResponseUnit(req(unit('unit',{expectedRevision:1,name:'Muudetud'})));
    assert.equal((await db.collection('unitRoster').get()).size,1);
  });
  test('units: concurrent allocations cannot count one member or vessel in two units; release and expiry permit reassignment',async()=>{
    const {h,now,advance,db}=await setup();
    await h.saveResponseUnit(req(unit('unit2')));
    const allocate=(id,revision=1)=>h.setUnitAllocation(req({id,expectedRevision:revision,memberIds:['active-member'],vesselIds:['boat'],validUntilMs:now()+3600000}));
    const results=await Promise.allSettled([allocate('unit'),allocate('unit2')]);
    assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
    assert.equal(results.find(r=>r.status==='rejected').reason.code,'failed-precondition');
    const data=await h.getOrganizationUnits(req({})),owner=data.units.find(u=>u.allocations.length),other=data.units.find(u=>!u.allocations.length);
    assert.equal(owner.allocations.length,2);
    await assert.rejects(h.saveResponseUnit(req(unit(owner.id,{expectedRevision:owner.revision,memberIds:[]}))),{code:'failed-precondition'});
    await h.setUnitAllocation(req({id:owner.id,expectedRevision:owner.revision,memberIds:[],vesselIds:[],validUntilMs:null}));
    await allocate(other.id,other.revision);
    advance(3600000);
    assert.ok((await h.getOrganizationUnits(req({}))).units.every(u=>u.allocations.length===0));
    await allocate(owner.id,owner.revision+1);
    assert.equal((await db.collection('resourceAllocations').get()).size,2);
    assert.ok((await db.collection('platformAudit').where('action','==','responseUnit.allocation').get()).size>=3);
  });
  test('units: verified duplicate vessel records and multi-org member use share global reservation keys',async()=>{
    const {db,h,now}=await setup();
    await db.doc('equipment/boat2').set({organizationId:org,scope:'organization',category:'vessel',name:'Sama alus'});
    for(const equipmentId of ['boat','boat2']) await db.doc(`vesselIdentities/${equipmentId}`).set({organizationId:org,physicalResourceId:'verified-hull',verified:true});
    await h.saveResponseUnit(req(unit('unit2',{vesselIds:['boat2']})));
    await assert.rejects(h.saveResponseUnit(req(unit('double',{vesselIds:['boat','boat2']}))),{code:'invalid-argument'});
    await h.setUnitAllocation(req({id:'unit',expectedRevision:1,memberIds:['active-member'],vesselIds:['boat'],validUntilMs:now()+3600000}));
    await assert.rejects(h.setUnitAllocation(req({id:'unit2',expectedRevision:1,memberIds:[],vesselIds:['boat2'],validUntilMs:now()+3600000})),{code:'failed-precondition'});
    await db.doc('memberships/org-admin_other-org').set({organizationId:'other-org',userId:'org-admin',role:'orgAdmin',status:'active',isActive:true});
    await db.doc('memberships/active-member_other-org').set({organizationId:'other-org',userId:'active-member',role:'member',status:'active',isActive:true});
    await h.saveRescueBase(req(base('other-base'),'org-admin','other-org'));
    await h.saveResponseUnit(req(unit('other-unit',{baseId:'other-base',vesselIds:[]}),'org-admin','other-org'));
    await assert.rejects(h.setUnitAllocation(req({id:'other-unit',expectedRevision:1,memberIds:['active-member'],vesselIds:[],validUntilMs:now()+3600000},'org-admin','other-org')),{code:'failed-precondition'});
  });
};
