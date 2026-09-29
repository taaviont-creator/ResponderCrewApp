const {createHash} = require('node:crypto');
function calloutNotificationPayload({calloutId,organizationId,calloutType = 'sar',tokens}) {
  const sar = calloutType !== 'tross';
  const channelId = sar ? 'sar_alarm_v2' : 'tross_callouts';
  const title = sar ? 'SAR-väljakutse häire' : 'Trossi mereabi väljakutse';
  const body = 'Uus väljakutse vajab reageerimist';
  return {tokens,notification:{title,body},data:{type:sar?'callout_alarm':'tross_callout',relatedType:'callout',
    calloutId,relatedId:calloutId,organizationId,calloutType:sar?'sar':'tross',channelId},
    android:{priority:'high',notification:{channelId,tag:calloutId,title,body,sound:sar?'sar_alarm':'default',
      priority:sar?'max':'default',defaultVibrateTimings:true,visibility:'private'}},
    apns:{headers:{'apns-collapse-id':createHash('sha256').update(calloutId).digest('hex')},payload:{aps:{sound:'default'}}}};
}
module.exports = {calloutNotificationPayload};
