// One evaluator for the center pilot, organization preview and generated demo fixtures.
// SAR uses the administrator-assigned membership level, as agreed on 2026-09-30.
function confirmationCurrent(confirmation, revision, now) {
  return !!confirmation && confirmation.revision === revision &&
    Number.isFinite(confirmation.confirmedAtMs) && confirmation.confirmedAtMs <= now &&
    ((confirmation.validityMode === 'untilChanged' && confirmation.validUntilMs === null) ||
      (confirmation.validityMode !== 'untilChanged' && Number.isFinite(confirmation.validUntilMs) && confirmation.validUntilMs > now));
}
function evaluateCenterReadiness({service,readiness:r,policy,confirmation,now,vessels=[],evidenceReady=false,revision=0,futureReadiness=null,automatic=false}) {
  const reasons=[];
  const minimum=service==='sar'?r.minimum:policy?.minimumResponders;
  const crew=r.crew || [];
  const current=crew.filter(m=>m.status==='onDuty');
  const qualified=members=>service!=='sar' || members.some(m=>m.level==='level2');
  const minimumValid=Number.isInteger(minimum) && minimum>0;
  const departure=policy?.departureMinutes;
  const configured=policy?.enabled===true && minimumValid && Number.isInteger(departure) && departure>0 && departure<=60;
  const checked=automatic || confirmationCurrent(confirmation,revision,now);
  const usable=vessels.some(v=>v.status==='ok');
  const uncertainVessel=vessels.some(v=>!['ok','broken','outOfService'].includes(v.status));
  const enough=minimumValid && current.length>=minimum && qualified(current);
  if(!configured) reasons.push('Teenuse tingimused on seadistamata.');
  if(!checked) reasons.push('Valmiduskinnitus puudub või on aegunud.');
  if(!evidenceReady) reasons.push('Ressursside kasutatavuse kontroll vajab lõpetamist.');
  if(r.paused) reasons.push('Ühing on valvest maas.');
  if(minimumValid && current.length<minimum) reasons.push(`Valves ${current.length}/${minimum} reageerijat.`);
  if(!qualified(current)) reasons.push('Valves olev II astme merepäästja puudub.');
  if(!usable) reasons.push(!vessels.length?'Teenuse alus puudub.':uncertainVessel?'Aluse kasutatavus vajab kontrollimist.':'Kasutatav alus puudub.');
  let status='unknown',expectedReadyAtMs=null;
  const delay=confirmation?.expectedReadyAtMs;
  const delayed=Number.isFinite(delay) && delay>now &&
    (confirmation?.validityMode==='untilChanged' || delay<confirmation?.validUntilMs);
  const future=crew.filter(m=>(!futureReadiness || futureReadiness.crew.some(f=>f.userId===m.userId && ['onDuty','delayed'].includes(f.status))) &&
    (m.status==='onDuty' || (m.status==='delayed' && Number.isInteger(m.arrivalMinutes) && m.arrivalMinutes>0 &&
      Math.max(confirmation?.confirmedAtMs ?? now,m.delayUpdatedAtMs ?? 0)+m.arrivalMinutes*60000<=delay)));
  // Known hard failures remain red even while positive resource proof is pending.
  // A persistent human confirmation cannot override an actual crew shortage.
  if(r.paused || confirmation?.unavailable===true) status='unavailable';
  else if(configured && checked) {
    if(!usable && !uncertainVessel) status='unavailable';
    else if(delayed) {
      if(future.length>=minimum && qualified(future)) {if(evidenceReady && usable) {status='delayed';expectedReadyAtMs=delay;}}
      else {status='unavailable';reasons.push('Kinnitatud väljasõiduajaks vajalik koosseis puudub.');}
    }
    else if(enough) {if(evidenceReady && usable) status='ready';}
    else status=Number.isFinite(delay) && delay<=now?'unknown':'unavailable';
  }
  if(confirmation?.unavailable===true) reasons.push('Ühing on kinnitanud teenuse kättesaamatuse.');
  if(status==='unknown' && Number.isFinite(delay) && delay<=now && !enough) reasons.push('Lubatud väljasõiduaeg on möödunud. Vajalik on uus kinnitus.');
  return {status,reasons:status==='ready'?[]:reasons,minimum:minimumValid?minimum:null,
    onDutyCount:current.length,secondLevelCount:current.filter(m=>m.level==='level2').length,
    departureMinutes:Number.isInteger(departure)?departure:null,expectedReadyAtMs,
    computedAtMs:now,confirmedAtMs:confirmation?.confirmedAtMs ?? null,
    freshUntilMs:Math.min(now+90000,!automatic && checked && Number.isFinite(confirmation?.validUntilMs)?confirmation.validUntilMs:now+90000,
      status==='delayed'?delay:now+90000)};
}
module.exports={evaluateCenterReadiness,confirmationCurrent};
