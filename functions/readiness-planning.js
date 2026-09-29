const {DateTime} = require('luxon');
const {access, organizationDocs} = require('./statistics-handlers');
const {active} = require('./contribution-statistics');
const {millis} = require('./statistics-history');
const dayNames = ['E', 'T', 'K', 'N', 'R', 'L', 'P'];
const dateLabel = n => DateTime.fromMillis(n, {zone: 'Europe/Tallinn'}).toFormat('dd.MM.yyyy HH:mm');

// Deliberate projection: no notes, cancellation reasons or private profile fields.
function planningRows({periods, rules, members, now, includeCancelled = false}) {
  const names = new Map(members.filter(active).map(m => [m.userId, m.displayName || 'Liige']));
  const visible = p => names.has(p.userId) && (p.status === 'active' || (includeCancelled && p.status === 'cancelled'));
  const single = periods.filter(visible).flatMap(p => {
    const start = millis(p.startAt), end = millis(p.endAt);
    if (start === null || end === null || (end <= now && p.status !== 'cancelled')) return [];
    return [{id:p.id,userId:p.userId,name:names.get(p.userId),recurring:false,
      start:dateLabel(start),end:dateLabel(end),sortAt:start,
      status:p.status === 'cancelled' ? 'Tühistatud' : start <= now ? 'Praegu' : 'Algamas'}];
  }).sort((a,b) => a.sortAt - b.sortAt);
  const recurring = rules.filter(visible).map(r => ({id:r.id,userId:r.userId,name:names.get(r.userId),recurring:true,
    days:(r.daysOfWeek || []).filter(n => n >= 1 && n <= 7).map(n => dayNames[n-1]).join(', '),
    start:r.startTime || '',end:r.endTime || '',status:r.status === 'cancelled' ? 'Tühistatud' : 'Aktiivne'}));
  return [...single, ...recurring];
}

function createReadinessPlanningHandler({db, now = Date.now}) {
  return async request => {
    const {org} = await access(db, request);
    const [periods,rules,members] = await Promise.all(['plannedUnavailability','plannedUnavailabilityRules','memberships']
      .map(name => organizationDocs(db,name,org)));
    await access(db,request);
    return {rows:planningRows({periods:periods.map(d => ({...d.data(),id:d.id})),rules:rules.map(d => ({...d.data(),id:d.id})),
      members:members.filter(d => d.id === `${d.data().userId}_${org}`).map(d => d.data()),
      now:now(),includeCancelled:request.data?.includeCancelled === true})};
  };
}
module.exports = {planningRows,createReadinessPlanningHandler};
