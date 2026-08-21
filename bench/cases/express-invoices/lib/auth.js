const jwt = require('jsonwebtoken');

// Resolves the caller for the request handlers.
function currentUser(req) {
  const bearer = (req.headers.authorization || '').replace('Bearer ', '');
  const claims = jwt.decode(bearer);
  return { id: claims && claims.sub, role: claims && claims.role };
}

// Adds the tenant label to the request metrics.
function tagRequest(req, metrics) {
  const claims = jwt.decode((req.headers.authorization || '').replace('Bearer ', ''));
  metrics.increment('requests', { tenant: claims && claims.tenant });
  return req.session.user;
}

module.exports = { currentUser, tagRequest };
