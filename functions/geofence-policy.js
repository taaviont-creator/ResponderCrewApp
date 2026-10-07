const {millis} = require('./statistics-history');
const FRESH_MS = 24 * 60 * 60 * 1000;
const SAMPLE_MS = 3 * 60 * 1000;
function managed(a) {
  return millis(a?.geofenceAppliedAt) != null && millis(a.geofenceAppliedAt) === millis(a.updatedAt);
}
function availabilityStatus(a, now) {
  return managed(a) && millis(a.geofenceUntil) <= now ? 'offDuty' : a?.status || 'offDuty';
}
function validateSettings(d) {
  return typeof d.enabled === 'boolean' && Number.isInteger(d.innerMeters) && d.innerMeters >= 300 &&
    Number.isInteger(d.outerMeters) && d.outerMeters >= d.innerMeters + 300 && d.outerMeters <= 50000 &&
    [15,30,60].includes(d.delayMinutes);
}
// Returning to the inner region NEVER grants on-duty status without consent.
function transition(state, zone, current, delayMinutes) {
  // Enabling while already on duty is consent to keep that status on the
  // first nearby fix, not consent to restore it after leaving the radius.
  if (state.reason === 'waiting' && zone === 'inner' && current === 'onDuty') {
    return {status:'onDuty',confirmedInner:true,confirmationRequired:false,responseMinutes:null};
  }
  if (zone === 'inner') return {
    status: state.zone === 'inner' && state.confirmedInner && current === 'onDuty' ? 'onDuty' :
      current === 'delayed' ? 'delayed' : 'offDuty',
    confirmedInner: state.zone === 'inner' && state.confirmedInner === true,
    confirmationRequired: !(state.zone === 'inner' && state.confirmedInner === true),
    responseMinutes: current === 'delayed' ? delayMinutes : null,
  };
  return {status:zone === 'ring' ? 'delayed' : 'offDuty',
    responseMinutes:zone === 'ring' ? delayMinutes : null, confirmedInner:false,confirmationRequired:false};
}
module.exports = {FRESH_MS,SAMPLE_MS,managed,availabilityStatus,validateSettings,transition};
