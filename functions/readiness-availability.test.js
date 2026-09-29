const {test} = require('node:test');
const assert = require('node:assert/strict');
const {unavailableMembers} = require('./readiness-availability');

test('readiness periods use inclusive start, exclusive end and ignore cancelled/future data', () => {
  const now = Date.parse('2026-09-29T09:00:00Z');
  const p = (userId, startAt, endAt, status = 'active') => ({userId, startAt, endAt, status, note: 'private'});
  assert.deepEqual(unavailableMembers([
    p('now', now, now + 1000), p('ended', now - 1000, now),
    p('future', now + 1000, now + 2000), p('cancelled', now - 1000, now + 1000, 'cancelled'),
  ], [], now), ['now']);
});
test('recurring readiness uses Tallinn weekdays/time through summer and winter', () => {
  const rule = {userId: 'member', status: 'active', daysOfWeek: [2], startMinute: 720, endMinute: 780};
  for (const date of ['2026-09-29T09:00:00Z', '2026-12-29T10:00:00Z']) {
    const at = Date.parse(date);
    assert.deepEqual(unavailableMembers([], [rule], at), ['member']);
    assert.deepEqual(unavailableMembers([], [rule], at + 3600000), []);
  }
});
