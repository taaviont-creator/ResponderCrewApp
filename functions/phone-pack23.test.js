const {test} = require('node:test');
const assert = require('node:assert/strict');
const {evaluateReadiness} = require('./effective-readiness');
const {readinessTransition,readinessMessage,createReadinessDelivery} = require('./organization-readiness');
const {preferences} = require('./notification-preferences');
const {planningRows} = require('./readiness-planning');
const {createPersonalDelivery} = require('./personal-notifications');
const {createMemberApplicationEmail,createOrganizationApplicationNotification} = require('./application-notifications');
const {calloutNotificationPayload} = require('./callout-notification-payload');
const {memoryDb} = require('./test-helpers/memory-db');
const now = Date.parse('2026-09-29T09:00:00Z');
const member = (uid,level='none',org='o') => ({id:`${uid}_${org}`,userId:uid,organizationId:org,status:'active',isActive:true,role:'member',displayName:uid,seaRescueLevel:level});
const base = {org:'o',organization:{status:'approved'},settings:{minimumCrewRequired:2},now,
  members:[member('a','level2'),member('b')],availability:['a','b'].map(userId=>({id:`${userId}_o`,userId,organizationId:'o',status:'onDuty'})),periods:[],rules:[]};
const evaluate = patch => evaluateReadiness({...base,...patch});
const logger = {info(){},warn(){},error(){}};

test('SAR needs minimum and an effective II member; pause and schedules take precedence',()=>{
  assert.equal(evaluate({}).ready,true);
  assert.equal(evaluate({settings:{minimumCrewRequired:3}}).ready,false);
  assert.equal(evaluate({members:[member('a'),member('b')]}).ready,false);
  assert.equal(evaluate({organization:{status:'approved',dutyPaused:true}}).ready,false);
  const absent = {organizationId:'o',userId:'a',status:'active',startAt:now,endAt:now+10000};
  const result = evaluate({periods:[absent]});
  assert.equal(result.onDutyCount,1);assert.equal(result.secondLevelMet,false);assert.equal(result.ready,false);
  assert.equal(evaluate({periods:[{...absent,status:'cancelled'}]}).ready,true);
  assert.equal(evaluate({rules:[{organizationId:'o',userId:'a',status:'active',daysOfWeek:[2],startMinute:720,endMinute:780}]}).ready,false);
});
test('readiness never counts foreign, spoofed or inactive membership and availability',()=>{
  const result = evaluate({members:[member('a','level2','other'),{...member('b'),id:'spoof'},{...member('c'),status:'removed'}]});
  assert.equal(result.onDutyCount,0);assert.deepEqual(result.crew,[]);
  assert.equal(evaluate({availability:base.availability.map(a=>({...a,commandId:'other'}))}).ready,false);
});
test('one departure coalesces minimum and II loss; unchanged state does not alert and restoration does',()=>{
  const before=evaluate({}),after=evaluate({availability:[base.availability[1]]});
  const lost=readinessTransition(before,after);
  assert.deepEqual(lost.keys,['readinessLost','belowMinimum','missingLevel2','memberOffDuty']);
  assert.match(readinessMessage(after,lost.keys).body,/Valves 1\/2.*II astme/);
  assert.match(readinessMessage(after,lost.keys).body,/Admin: kontrolli koosseisu/);
  assert.equal(after.paused,false); // A shortage alerts; only the admin controls organizational suspension.
  assert.deepEqual(readinessTransition(after,after).keys,[]);
  assert.deepEqual(readinessTransition(null,after).keys,[]);
  assert.deepEqual(readinessTransition(after,before).keys,['readinessRestored']);
});
test('defaults are role-specific and explicit off wins even for admin',()=>{
  assert.equal(preferences('orgAdmin').readinessLost,true);
  assert.equal(preferences('member').readinessLost,false);
  assert.equal(preferences('platformAdmin').readinessLost,false);
  assert.equal(preferences('admin',{readinessLost:false}).readinessLost,false);
  assert.equal(preferences('member',{newCallout:'false'}).newCallout,true);
});
test('recipient preferences choose one combined push for org loss plus own absence',async()=>{
  const delivered=[];
  const handler=createReadinessDelivery({deliver:async d=>delivered.push(d),preferencesFor:async(_org,uid)=>preferences(uid==='a'?'orgAdmin':'member',uid==='b'?{ownAbsenceStarted:false}:{})});
  const after=evaluate({availability:[base.availability[1]]});
  await handler({params:{eventId:'e'},data:{data:()=>({organizationId:'o',keys:['readinessLost','belowMinimum','missingLevel2'],started:['a','b'],ended:[],memberIds:['a','b'],after})}});
  assert.equal(delivered.length,1);assert.equal(delivered[0].uid,'a');assert.match(delivered[0].body,/Sinu planeeritud mittevalve algas/);
  assert.match(delivered[0].body,/kas ühing jätkab valves/);
});
test('shared planning excludes private notes, expired and cancelled rows by default',()=>{
  const period={id:'p',userId:'a',status:'active',startAt:now,endAt:now+10000,note:'PRIVATE'};
  const data={members:base.members,now,periods:[period,{...period,id:'end',endAt:now},{...period,id:'cancel',status:'cancelled'},{...period,id:'outsider',userId:'foreign'}],rules:[]};
  const rows=planningRows(data);assert.equal(rows.length,1);assert.equal(rows[0].status,'Praegu');assert.doesNotMatch(JSON.stringify(rows),/PRIVATE|note/);
  assert.equal(planningRows({...data,includeCancelled:true}).length,2);
});
test('SAR and Tross share exact callout routing but use distinct sound/importance channels',()=>{
  const sar=calloutNotificationPayload({calloutId:'exact',organizationId:'o',tokens:['t']});
  const tross=calloutNotificationPayload({calloutId:'exact',organizationId:'o',calloutType:'tross',tokens:['t']});
  assert.equal(sar.android.priority,'high');assert.equal(sar.android.notification.sound,'sar_alarm');
  assert.equal(sar.android.notification.channelId,'sar_alarm_v2');assert.equal(tross.android.notification.channelId,'tross_callouts');
  assert.equal(tross.android.notification.priority,'default');assert.equal(tross.data.calloutId,'exact');
  assert.equal(sar.data.calloutId,'exact');assert.equal(sar.data.organizationId,'o');
});
test('personal delivery respects off, membership boundaries, and keeps inbox without a device',async()=>{
  const {db,records}=memoryDb({'commands/o':{status:'approved'},'memberships/a_o':member('a'),
    'notificationPreferences/a_o':{preferences:{readinessLost:false}}});
  const deliver=createPersonalDelivery({db,logger,loadTokens:async()=>[],messaging:{sendEachForMulticast:()=>assert.fail('No devices')}});
  const message={sourceId:'e',org:'o',uid:'a',title:'Title',body:'Body',relatedType:'organizationReadiness',preferenceKeys:['readinessLost']};
  await deliver(message);assert.equal([...records.keys()].filter(k=>k.startsWith('userNotifications/')).length,0);
  records.set('notificationPreferences/a_o',{preferences:{readinessLost:true}});
  await deliver(message);await deliver(message);assert.equal([...records.keys()].filter(k=>k.startsWith('userNotifications/')).length,1);
  await deliver({...message,sourceId:'foreign',org:'other'});assert.equal([...records.keys()].filter(k=>k.startsWith('userNotifications/')).length,1);
});

test('dispatch information uses exact callout routing and a separate channel without a second SAR alarm',async()=>{
  const {db}=memoryDb({'commands/o':{status:'approved'},'memberships/a_o':member('a')});
  const sent=[];
  const deliver=createPersonalDelivery({db,logger,loadTokens:async()=>[{token:'device'}],messaging:{sendEachForMulticast:async data=>{sent.push(data);return {failureCount:0};}}});
  const message={sourceId:'critical',org:'o',uid:'a',title:'Keskuse info',body:'Ava väljakutse',type:'callout',relatedType:'callout',relatedId:'callout-exact',pushType:'callout_update',urgent:true};
  await deliver(message);await deliver(message);
  assert.equal(sent.length,1);assert.equal(sent[0].data.type,'callout_update');assert.equal(sent[0].data.relatedId,'callout-exact');
  assert.equal(sent[0].android.notification.channelId,'dispatch_updates');assert.equal(sent[0].android.priority,'high');assert.equal(sent[0].android.notification.sound,undefined);
  await deliver({...message,sourceId:'routine',urgent:false});
  assert.equal(sent[1].android.notification.channelId,'respondcrew_info');assert.equal(sent[1].android.priority,'normal');
});
test('membership email goes only to active org admins via Auth and is idempotent/minimal',async()=>{
  const applicant={userId:'applicant',organizationId:'o',role:'member',status:'pending',isActive:false,displayName:'Taotleja',joinedAt:new Date(now)};
  const {db,records}=memoryDb({'commands/o':{status:'approved',name:'Päästeühing'},'memberships/applicant_o':applicant,
    'memberships/a_o':{...member('a'),role:'orgAdmin'},'memberships/b_o':member('b'),
    'memberships/foreign_other':{...member('foreign','none','other'),role:'orgAdmin'},'users/platform':{systemRole:'platformAdmin'}});
  const sent=[];
  const handler=createMemberApplicationEmail({db,logger,auth:{getUser:async uid=>({email:`${uid}@example.ee`})},sendMail:async mail=>{sent.push(mail);return {accepted:[mail.to.address]};}});
  const event={id:'application',params:{membershipId:'applicant_o'},data:{before:{data:()=>undefined},after:await db.doc('memberships/applicant_o').get()}};
  await handler(event);await handler(event);assert.equal(sent.length,1);assert.equal(sent[0].to.address,'a@example.ee');
  assert.match(sent[0].text,/Taotleja.*Päästeühing/);assert.doesNotMatch(sent[0].text,/applicant@|phone|isikukood/);
  records.set('memberships/applicant_o',{...applicant,status:'active'});await handler({...event,id:'reviewed'});assert.equal(sent.length,1);
});
test('platform application selects platform roles only and ignores already reviewed applications',async()=>{
  const {db,records}=memoryDb({'commands/new':{name:'Uus',status:'pending',createdBy:'a',createdAt:new Date(now)},
    'users/p':{systemRole:'platformAdmin'},'users/a':{systemRole:'user',role:'orgAdmin'}});
  const sent=[],handler=createOrganizationApplicationNotification({db,deliver:async d=>sent.push(d)});
  const event={params:{organizationId:'new'},data:await db.doc('commands/new').get()};
  await handler(event);assert.deepEqual(sent.map(d=>d.uid),['p']);assert.equal(sent[0].platform,true);
  records.set('commands/new',{status:'approved'});await handler(event);assert.equal(sent.length,1);
});


test('callout payload passes Firebase Admin wire conversion with valid Android priority fields',()=>{
 const path=require('node:path');
 const {validateMessage}=require(path.join(path.dirname(require.resolve('firebase-admin')),'messaging/messaging-internal.js'));
 for(const calloutType of ['sar','tross']) {
  const {tokens,...payload}=calloutNotificationPayload({calloutId:'c',organizationId:'o',calloutType,tokens:['test-token']});
  const message={...payload,token:tokens[0]};
  validateMessage(message);
  assert.equal(message.android.notification.notification_priority,calloutType==='sar'?'PRIORITY_MAX':'PRIORITY_DEFAULT');
  assert.equal(message.android.notification.channel_id,calloutType==='sar'?'sar_alarm_v2':'tross_callouts');
  assert.equal(Object.hasOwn(message.android.notification,'notificationPriority'),false);
  assert.equal(Object.hasOwn(message.android.notification,'priority'),false);
  assert.equal(message.android.notification.visibility,'PRIVATE');
 }
});
