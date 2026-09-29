const {access} = require('./statistics-handlers');
const {unavailableMembers} = require('./effective-readiness');
const {loadReadiness} = require('./organization-readiness');
function createReadinessAvailabilityHandler({db, now = Date.now}) {
  return async request => {
    const {org} = await access(db,request);
    const readiness = await loadReadiness(db,org,now());
    await access(db,request);
    return readiness;
  };
}
module.exports = {unavailableMembers,createReadinessAvailabilityHandler};
