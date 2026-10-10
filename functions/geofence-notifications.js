// Keep the existing trigger name; one personal inbox item/push per transition.
// getState uses the callable's membership/manual/absence/expiry checks.
function createGeofenceNotifications({getState,deliver}) {
  return async event=>{
    const before=event.data?.before.data(), after=event.data?.after.data();
    if(!after) return;
    const returning=after.enabled && after.confirmationRequired && !before?.confirmationRequired;
    const expired=before?.enabled && !after.enabled && after.reason==='stale';
    const change=after.statusChange;
    const changed=after.enabled && change && change.atMs!==before?.statusChange?.atMs;
    if(!returning && !expired && !changed) return;
    let current;
    try { current=await getState(after); }
    catch(error) { if(error.code==='permission-denied') return; throw error; }
    if(current?.sessionId!==after.sessionId || current.reason==='plannedAbsence') return;
    let title,body,kind;
    if(returning && current.enabled && current.confirmationRequired) {
      title='Oled tagasi valvesoleku piirkonnas?';
      body='Telefon tuvastas võimaliku naasmise. Ava valmisolek, kontrolli asukohta ja kinnita, kui saad reageerida. Valvesse märkimine vajab sinu kinnitust.'+
        (current.zone==='unknown'?' Seni oled mitte valves.':'');
      kind='return';
    } else if(expired && !current.enabled && current.reason==='stale') {
      title='Asukohapõhine valmisolek aegus';
      body='24 tunni jooksul ei tulnud uut asukohakinnitust. Oled automaatika järgi mitte valves. Ava valmisolek ja kontrolli oma staatust.';
      kind='expired';
    } else if(changed && current.enabled && current.statusChange?.atMs===change.atMs &&
      current.zone===change.zone && ['observed','locationUnavailable','returnCandidate'].includes(current.reason)) {
      if(change.to==='delayed') {
        title='Asukohapõhine valve: hilinemisega';
        body=`Lahkusid valvesoleku raadiusest. Automaatika märkis sind hilinemisega valvesse (+${change.responseMinutes} min).`;
      } else if(change.to==='offDuty') {
        title='Asukohapõhine valve: mitte valves';
        body=change.zone==='outside' ? 'Lahkusid ka hilinemisega valve raadiusest. Automaatika märkis sind mitte valvesse.' :
          'Telefon ei saanud sinu asukohta piisavalt täpselt kinnitada. Automaatika märkis sind mitte valvesse. Ava valmisolek ja kontrolli asukohta.';
      } else return;
      kind='status';
    } else return;
    await deliver({sourceId:`geofence:${event.id}:${kind}`,org:after.organizationId,uid:after.userId,
      title,body,type:'availability',relatedType:'personalAvailability',timeSensitive:true});
  };
}
module.exports={createGeofenceNotifications};
