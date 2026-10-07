const {createHash} = require('node:crypto');
function calloutNotificationPayload({calloutId,organizationId,calloutType = 'sar',tokens,nativeSarAlarm = false,isTest = false}) {
  const sar = calloutType !== 'tross';
  const channelId = sar ? 'sar_alarm_v2' : 'tross_callouts';
  const title = isTest ? (sar ? 'PROOVIHÄIRE · SAR' : 'PROOVIHÄIRE · Trossi mereabi') : (sar ? 'SAR-väljakutse häire' : 'Trossi mereabi väljakutse');
  const body = isTest ? 'Ühingu meeskonna harjutus. Tegemist ei ole päris sündmusega.' : 'Uus väljakutse vajab reageerimist';
  if (sar && nativeSarAlarm) {
    return {tokens, data: {type:'callout_alarm', relatedType:'callout', calloutId,
      relatedId:calloutId, organizationId, calloutType:'sar', channelId, title, body,
      isTest:String(isTest), delivery:'native_sar_v1'}, android:{priority:'high', ttl:300000}};
  }
  return {tokens,notification:{title,body},data:{type:sar?'callout_alarm':'tross_callout',relatedType:'callout',
    calloutId,relatedId:calloutId,organizationId,calloutType:sar?'sar':'tross',channelId,isTest:String(isTest)},
    android:{priority:'high',notification:{channelId,tag:calloutId,title,body,sound:sar?'sar_alarm':'default',
      priority:sar?'max':'default',defaultVibrateTimings:true,visibility:'private'}},
    apns:{headers:{'apns-collapse-id':createHash('sha256').update(calloutId).digest('hex')},payload:{aps:{sound:'default'}}}};
}
function calloutDeliveryGroups(records, calloutType) {
  const native = [], legacy = [];
  for (const record of records) {
    (calloutType !== 'tross' && record.platform === 'android' && record.nativeSarAlarm === true ? native : legacy).push(record);
  }
  return [{nativeSarAlarm:true, records:native}, {nativeSarAlarm:false, records:legacy}].filter(group=>group.records.length);
}
module.exports = {calloutNotificationPayload, calloutDeliveryGroups};
