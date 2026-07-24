const User = require('../models/User');
const { createRefreshToken, hashRefreshToken, signAuthToken } = require('../utils/token');

const SAFE_USER_FIELDS = '-passwordHash';
const SELF_REGISTER_ROLES = new Set(['patient', 'doctor']);

function normalizeEmail(email) {
  return String(email || '').trim().toLowerCase();
}

function assertValidEmail(email) {
  if (!/^\S+@\S+\.\S+$/.test(email)) {
    const error = new Error('Please provide a valid email');
    error.statusCode = 400;
    throw error;
  }
}

function assertValidPassword(password) {
  if (typeof password !== 'string' || password.length < 8) {
    const error = new Error('Password must be at least 8 characters');
    error.statusCode = 400;
    throw error;
  }
}

function normalizeRole(role) {
  const normalized = String(role || 'patient').trim().toLowerCase();
  if (!SELF_REGISTER_ROLES.has(normalized)) {
    const error = new Error('Role must be patient or doctor');
    error.statusCode = 400;
    throw error;
  }
  return normalized;
}

function publicUser(user) {
  const json = user.toJSON ? user.toJSON() : user;
  delete json.passwordHash;
  return json;
}

function authPayload(user, refreshToken) {
  return {
    token: signAuthToken(user),
    refreshToken,
    user: publicUser(user),
  };
}

async function issueRefreshToken(user) {
  const refresh = createRefreshToken();
  user.refreshTokens = (user.refreshTokens || [])
    .filter((item) => !item.revokedAt && item.expiresAt > new Date())
    .slice(-4);
  user.refreshTokens.push({
    tokenHash: refresh.tokenHash,
    expiresAt: refresh.expiresAt,
  });
  await user.save();
  return refresh.token;
}

async function register(req, res, next) {
  try {
    const email = normalizeEmail(req.body.email);
    const {
      password,
      firstName = 'ReJoy',
      surname = 'Friend',
      age = 0,
      role,
    } = req.body;
    const normalizedRole = normalizeRole(role);

    assertValidEmail(email);
    assertValidPassword(password);

    const existing = await User.findOne({ email }).lean();
    if (existing) {
      return res.status(409).json({ message: 'Email is already registered' });
    }

    const user = new User({
      firstName,
      surname,
      age,
      role: normalizedRole,
      email,
      authProvider: 'email',
      onboardingComplete: normalizedRole !== 'patient',
      allergies: [],
      emergencyContactNumbers: [],
      currentMedications: [],
      symptomClusteringMatrix: [],
      selectedQuestsToday: [],
      completedQuestsToday: [],
      unlockedAnimals: [],
    });
    await user.setPassword(password);
    const refreshToken = await issueRefreshToken(user);

    return res.status(201).json(authPayload(user, refreshToken));
  } catch (error) {
    return next(error);
  }
}

async function login(req, res, next) {
  try {
    const email = normalizeEmail(req.body.email);
    const { password } = req.body;

    assertValidEmail(email);
    assertValidPassword(password);

    const user = await User.findOne({ email }).select('+passwordHash');
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ message: 'Invalid email or password' });
    }

    const refreshToken = await issueRefreshToken(user);

    return res.json(authPayload(user, refreshToken));
  } catch (error) {
    return next(error);
  }
}

async function me(req, res, next) {
  try {
    const user = await User.findById(req.user._id).select(SAFE_USER_FIELDS);
    return res.json({ user });
  } catch (error) {
    return next(error);
  }
}

async function refresh(req, res, next) {
  try {
    const token = req.body.refreshToken;
    if (!token) {
      return res.status(400).json({ message: 'refreshToken is required' });
    }

    const tokenHash = hashRefreshToken(token);
    const user = await User.findOne({ 'refreshTokens.tokenHash': tokenHash });
    if (!user) {
      return res.status(401).json({ message: 'Invalid refresh token' });
    }

    const refreshRecord = user.refreshTokens.find(
      (item) => item.tokenHash === tokenHash,
    );
    if (
      !refreshRecord ||
      refreshRecord.revokedAt ||
      refreshRecord.expiresAt <= new Date()
    ) {
      return res.status(401).json({ message: 'Refresh token expired' });
    }

    refreshRecord.revokedAt = new Date();
    const refreshToken = await issueRefreshToken(user);
    return res.json(authPayload(user, refreshToken));
  } catch (error) {
    return next(error);
  }
}

async function logout(req, res, next) {
  try {
    const token = req.body.refreshToken;
    if (token) {
      const tokenHash = hashRefreshToken(token);
      await User.updateOne(
        { _id: req.user._id, 'refreshTokens.tokenHash': tokenHash },
        { $set: { 'refreshTokens.$.revokedAt': new Date() } },
      );
    }
    return res.json({ message: 'Logged out' });
  } catch (error) {
    return next(error);
  }
}

module.exports = {
  login,
  logout,
  me,
  refresh,
  register,
};
