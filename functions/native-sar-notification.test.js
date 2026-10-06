const {test}=require('node:test');
const assert=require('node:assert/strict');
const {calloutDeliveryGroups,calloutNotificationPayload}=require('./callout-notification-payload');
test('only capable Android SAR clients receive data-only alarm delivery',()=>{
  const records=[{token:'new',platform:'android',nativeSarAlarm:true},
    {token:'old',platform:'android'}, {token:'apple',platform:'ios',nativeSarAlarm:true}];
  const groups=calloutDeliveryGroups(records,'sar');
  assert.deepEqual(groups.map(g=>g.records.map(r=>r.token)),[['new'],['old','apple']]);
  assert.deepEqual(calloutDeliveryGroups(records,'tross'),[{nativeSarAlarm:false,records}]);
  assert.deepEqual(calloutDeliveryGroups([],'sar'),[]);
});
test('native SAR contains exact route, high priority and bounded lifetime without OS duplicate',()=>{
  const message=calloutNotificationPayload({calloutId:'exact',organizationId:'org',tokens:['new'],nativeSarAlarm:true});
  assert.equal(message.notification,undefined);
  assert.equal(message.android.notification,undefined);
  assert.equal(message.android.priority,'high');
  assert.equal(message.android.ttl,300000);
  assert.equal(message.data.calloutId,'exact');
  assert.equal(message.data.organizationId,'org');
  assert.equal(message.data.delivery,'native_sar_v1');
  const path=require('node:path');
  const {validateMessage}=require(path.join(path.dirname(require.resolve('firebase-admin')),'messaging/messaging-internal.js'));
  const {tokens,...payload}=message;
  validateMessage({...payload,token:tokens[0]});
});
test('legacy Android, iOS and Tross retain their existing system notifications',()=>{
  const legacy=calloutNotificationPayload({calloutId:'c',organizationId:'org',tokens:['old']});
  assert.equal(legacy.android.notification.channelId,'sar_alarm_v2');
  assert.ok(legacy.notification);
  assert.equal(legacy.apns.payload.aps.sound,'default');
  const tross=calloutNotificationPayload({calloutId:'c',organizationId:'org',tokens:['new'],nativeSarAlarm:true,calloutType:'tross'});
  assert.equal(tross.android.notification.channelId,'tross_callouts');
  assert.ok(tross.notification);
  assert.equal(tross.data.delivery,undefined);
});
