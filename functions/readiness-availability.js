const {DateTime} = require('luxon');
const {access, organizationDocs} = require('./statistics-handlers');
const {millis} = require('./statistics-history');

// Return only the current operational effect of private schedules. Never
// expose absence notes, future dates, or recurring patterns to other members.
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

function createReadinessAvailabilityHandler({db, now = () => Date.now()}) {
  return async request => {
    const {org} = await access(db, request);
    const [periods, rules] = await Promise.all([
      organizationDocs(db, 'plannedUnavailability', org),
      organizationDocs(db, 'plannedUnavailabilityRules', org),
    ]);
    // Recheck membership after loading private data before disclosing its effect.
    await access(db, request);
    return {unavailableUserIds: unavailableMembers(
      periods.map(d => d.data()), rules.map(d => d.data()), now(),
    )};
  };
}
module.exports = {unavailableMembers, createReadinessAvailabilityHandler};
