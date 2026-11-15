const { findUserByToken } = require('../services/authStore');

function requireAdmin(req, res, next) {
  if (req.authUser?.role !== 'admin') {
    return res.status(403).json({ error: 'Administrator access is required.' });
  }
  return next();
}

function authenticate({ optional = false } = {}) {
  return async (req, res, next) => {
    try {
      const authorization = req.get('authorization');
      if (!authorization && optional) return next();

      const match = /^Bearer ([A-Za-z0-9_-]+)$/i.exec(authorization || '');
      if (!match) {
        return res
          .status(401)
          .json({ error: 'A valid bearer token is required.' });
      }

      const user = await findUserByToken(match[1]);
      if (!user) {
        return res.status(401).json({ error: 'Session is invalid or expired.' });
      }

      req.authUser = user;
      req.authToken = match[1];
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

module.exports = {
  optionalAuth: authenticate({ optional: true }),
  requireAuth: authenticate(),
  requireAdmin,
};
