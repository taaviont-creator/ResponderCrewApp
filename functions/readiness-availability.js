const {access} = require('./statistics-handlers');
const {unavailableMembers} = require('./effective-readiness');
function createReadinessAvailabilityHandler({db, now = Date.now}) {
  return async request => {
    const {org} = await access(db,request);
    const readiness = await require('./operational-readiness').loadOperationalReadiness(db,org,now());
    await access(db,request);
    return readiness;
  };
}
module.exports = {unavailableMembers,createReadinessAvailabilityHandler};
