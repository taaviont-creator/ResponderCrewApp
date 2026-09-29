const {createMemberApplicationNotification} = require('./application-notifications');
const {createPersonalDelivery} = require('./personal-notifications');
// Preserve the existing trigger's name and entry point; all channels share one inbox pipeline.
function createMemberRequestHandler(dependencies) {
  return createMemberApplicationNotification({db:dependencies.db,deliver:createPersonalDelivery(dependencies)});
}
module.exports = {createMemberRequestHandler};
