const User = require('../models/User');
const { verifyAuthToken } = require('../utils/token');

const AUTH_USER_FIELDS = [
  '_id',
  'email',
  'role',
  'onboardingComplete',
  'assignedClinicianIds',
].join(' ');

async function requireAuth(req, res, next) {
  try {
    const header = req.get('authorization') || '';
    const [scheme, token] = header.split(' ');

    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    const payload = verifyAuthToken(token);
    const user = await User.findById(payload.sub)
      .select(AUTH_USER_FIELDS)
      .lean();

    if (!user) {
      return res.status(401).json({ message: 'User no longer exists' });
    }

    req.user = user;
    return next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
}

function requireSelf(req, res, next) {
  if (!req.user || req.user._id.toString() !== req.params.id) {
    return res.status(403).json({ message: 'You can only access your own data' });
  }
  return next();
}

module.exports = {
  requireAuth,
  requireSelf,
};
