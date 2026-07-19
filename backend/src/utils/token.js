const jwt = require('jsonwebtoken');
const crypto = require('crypto');

function getJwtSecret() {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) {
    throw new Error('JWT_SECRET must be set and at least 32 characters long');
  }
  return secret;
}

function signAuthToken(user) {
  return jwt.sign(
    {
      sub: user._id.toString(),
      email: user.email,
    },
    getJwtSecret(),
    {
      expiresIn: process.env.JWT_EXPIRES_IN || '7d',
      issuer: 'rejoy-backend',
      audience: 'rejoy-mobile',
    },
  );
}

function createRefreshToken() {
  const token = crypto.randomBytes(48).toString('base64url');
  const tokenHash = hashRefreshToken(token);
  const expiresInDays = Number(process.env.REFRESH_TOKEN_EXPIRES_DAYS || 30);
  const expiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);
  return { token, tokenHash, expiresAt };
}

function hashRefreshToken(token) {
  return crypto.createHash('sha256').update(String(token)).digest('hex');
}

function verifyAuthToken(token) {
  return jwt.verify(token, getJwtSecret(), {
    issuer: 'rejoy-backend',
    audience: 'rejoy-mobile',
  });
}

module.exports = {
  createRefreshToken,
  hashRefreshToken,
  signAuthToken,
  verifyAuthToken,
};
