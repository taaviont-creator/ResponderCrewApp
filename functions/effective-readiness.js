const {DateTime} = require('luxon');
const {millis,orgId} = require('./statistics-history');
const {active} = require('./contribution-statistics');
function unavailableMembers(periods, rules, now) {
  const clock = DateTime.fromMillis(now, {zone: 'Europe/Tallinn'});
  const minute = clock.hour * 60 + clock.minute;
  const ids = new Set();
  for (const p of periods) {
    const start = millis(p.startAt), end = millis(p.endAt);
    if (p.status === 'active' && start !== null && end !== null &&
        start <= now && now < end) ids.add(p.userId);
  }
  for (const r of rules) {
    if (r.status === 'active' && r.daysOfWeek?.includes(clock.weekday) &&
        minute >= r.startMinute && minute < r.endMinute) ids.add(r.userId);
  }
  return [...ids].filter(id => typeof id === 'string' && id.length > 0).sort();
}


// Authoritative SAR evaluation used by both the UI endpoint and transition job.
function evaluateReadiness({org,organization,settings,members,availability,periods,rules,now}) {
  const scoped = rows => rows.filter(r => orgId(r) === org);
  const roster = scoped(members).filter(m => active(m) && m.id === `${m.userId}_${org}`);
  const unavailable = new Set(unavailableMembers(scoped(periods),scoped(rules),now));
  const byUser = new Map(scoped(availability).filter(a => a.id === `${a.userId}_${org}`).map(a => [a.userId,a]));
  const crew = roster.map(m => {
    const a = byUser.get(m.userId), manual = require('./geofence-policy').availabilityStatus(a,now);
    const status = unavailable.has(m.userId) || !['onDuty','delayed'].includes(manual) ? 'offDuty' : manual;
    return {userId:m.userId,name:m.displayName || 'Liige',level:m.seaRescueLevel || 'none',status,
      arrivalMinutes:status === 'delayed' && Number.isInteger(a?.responseMinutes) ? a.responseMinutes : null,
      delayUpdatedAtMs:status === 'delayed' ? millis(a?.updatedAt) : null};
  }).sort((a,b) => a.name.localeCompare(b.name,'et'));
  const onDuty = crew.filter(m => m.status === 'onDuty');
  const minimum = Number.isInteger(settings?.minimumCrewRequired) ? Math.max(0,settings.minimumCrewRequired) : 0;
  const paused = organization.dutyPaused === true || organization.status !== 'approved';
  const minimumMet = minimum > 0 && onDuty.length >= minimum;
  const secondLevelMet = onDuty.some(m => m.level === 'level2');
  const ready = !paused && minimumMet && secondLevelMet;
  const missing = paused ? ['Ühing on valvest maas'] : minimum === 0 ? ['Miinimumkoosseis ei ole seadistatud'] :
    [...(!minimumMet ? ['Miinimumkoosseis puudu'] : []),...(!secondLevelMet ? ['II astme merepäästja puudub'] : [])];
  return {ready,minimum,minimumMet,secondLevelMet,paused,pauseReason:organization.dutyPauseReason || '',
    onDutyCount:onDuty.length,delayedCount:crew.filter(m => m.status === 'delayed').length,
    secondLevelOnDutyCount:onDuty.filter(m => m.level === 'level2').length,
    dutyUserIds:onDuty.map(m => m.userId).sort(),unavailableUserIds:roster.map(m=>m.userId).filter(uid=>unavailable.has(uid)).sort(),
    missing,crew};
}
module.exports = {unavailableMembers,evaluateReadiness};
