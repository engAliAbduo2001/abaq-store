const {
  randomBytes,
  randomUUID,
  scryptSync,
  timingSafeEqual,
} = require('node:crypto');
const { database } = require('../database');

const sessions = new Map();
const sessionLifetimeMs = 7 * 24 * 60 * 60 * 1000;

function normalizeEmail(email) {
  return email.trim().toLowerCase();
}

async function createUser({ name, email, phone, address, password }) {
  const normalizedEmail = normalizeEmail(email);
  const salt = randomBytes(16);
  const user = {
    id: randomUUID(),
    name: name.trim(),
    email: normalizedEmail,
    phone: phone.trim(),
    address: address.trim(),
    role: 'customer',
    salt: salt.toString('hex'),
    passwordHash: scryptSync(password, salt, 64).toString('hex'),
    createdAt: new Date().toISOString(),
  };
  return database.createUser(user);
}

function findUserByEmail(email) {
  return database.getUserByEmail(normalizeEmail(email));
}

function findUserById(userId) {
  return database.getUserById(userId);
}

function verifyPassword(user, password) {
  const candidate = scryptSync(password, Buffer.from(user.salt, 'hex'), 64);
  const savedHash = Buffer.from(user.passwordHash, 'hex');
  return timingSafeEqual(candidate, savedHash);
}

function createSession(userId) {
  const token = randomBytes(32).toString('base64url');
  sessions.set(token, {
    userId,
    expiresAt: Date.now() + sessionLifetimeMs,
  });
  return token;
}

async function findUserByToken(token) {
  const session = sessions.get(token);
  if (!session) return undefined;
  if (session.expiresAt <= Date.now()) {
    sessions.delete(token);
    return undefined;
  }
  return database.getUserById(session.userId);
}

function revokeSession(token) {
  sessions.delete(token);
}

function publicProfile(user) {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    address: user.address,
    role: user.role,
  };
}

module.exports = {
  createSession,
  createUser,
  findUserByEmail,
  findUserById,
  findUserByToken,
  normalizeEmail,
  publicProfile,
  revokeSession,
  verifyPassword,
};
