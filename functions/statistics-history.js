const {createHash} = require('node:crypto');
const SOURCES = ['availability', 'memberships', 'plannedUnavailability', 'plannedUnavailabilityRules'];
const orgId = d => d?.organizationId && d?.commandId && d.organizationId !== d.commandId ? null : d?.organizationId || d?.commandId;
const millis = value => value?.toMillis ? value.toMillis() : value instanceof Date ? +value : typeof value === 'number' ? value : null;
// Keep only fields needed for time accounting, never phone, email, notes or GPS.
function project(source, data) {
  if (!data) return null;
  const result = {userId:data.userId || '', organizationId:orgId(data) || ''};
  const fields = {availability:['status'], memberships:['status','isActive','joinedAt','displayName'],
    plannedUnavailability:['status','startAt','endAt'], plannedUnavailabilityRules:['status','daysOfWeek','startMinute','endMinute']}[source];
  for (const field of fields || []) if (data[field] !== undefined) result[field] = ['joinedAt','startAt','endAt'].includes(field) ? millis(data[field]) : data[field];
  return result;
}
function createHistoryHandler({db, source}) {
  if (!SOURCES.includes(source)) throw Error('Unknown history source');
  return async event => {
    if (!event.data || !event.id) return;
    const before = project(source, event.data.before.data());
    const after = project(source, event.data.after.data());
    const org = orgId(after) || orgId(before);
    if (!org || !(after?.userId || before?.userId)) return;
    const at = millis(event.data.after.updateTime) ?? Date.parse(event.time);
    if (!Number.isFinite(at)) throw Error('Missing source commit time');
    const id = createHash('sha256').update(`${source}:${event.id}`).digest('hex');
    try {
      await db.collection('statisticsHistory').doc(id).create({organizationId:org, source, sourceId:event.params.documentId,
        userId:after?.userId || before.userId, at, before, after});
    } catch(error) { if(error.code !== 6 && error.code !== 'already-exists') throw error; }
  };
}
module.exports = {SOURCES, orgId, millis, project, createHistoryHandler};
