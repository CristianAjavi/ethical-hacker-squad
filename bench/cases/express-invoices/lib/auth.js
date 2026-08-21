const jwt = require('jsonwebtoken');

// Planted: the payload is decoded, never verified, and it decides the role.
function currentUser(req) {
  const bearer = (req.headers.authorization || '').replace('Bearer ', '');
  const claims = jwt.decode(bearer);
  return { id: claims && claims.sub, role: claims && claims.role };
}

// Decoy: decode() again, and here it only feeds a metric. Authorization is
// resolved from the server-side session.
function tagRequest(req, metrics) {
  const claims = jwt.decode((req.headers.authorization || '').replace('Bearer ', ''));
  metrics.increment('requests', { tenant: claims && claims.tenant });
  return req.session.user;
}

module.exports = { currentUser, tagRequest };
