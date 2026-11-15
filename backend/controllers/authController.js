const {
  createSession,
  createUser,
  findUserByEmail,
  publicProfile,
  revokeSession,
  verifyPassword,
} = require('../services/authStore');

function validateRegistration(body) {
  const errors = [];
  if (typeof body.name !== 'string' || body.name.trim().length < 2) {
    errors.push('name must be at least 2 characters.');
  }
  if (
    typeof body.email !== 'string' ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(body.email.trim())
  ) {
    errors.push('email must be valid.');
  }
  if (typeof body.phone !== 'string') {
    errors.push('phone must be valid.');
  } else {
    const digits = body.phone.replace(/\D/g, '');
    if (digits.length < 7 || digits.length > 15) {
      errors.push('phone must contain 7 to 15 digits.');
    }
  }
  if (typeof body.address !== 'string' || body.address.trim().length < 5) {
    errors.push('address must be at least 5 characters.');
  }
  if (
    typeof body.password !== 'string' ||
    body.password.length < 6 ||
    body.password.length > 128
  ) {
    errors.push('password must be between 6 and 128 characters.');
  }
  return errors;
}

async function register(req, res) {
  const body = req.body && typeof req.body === 'object' ? req.body : {};
  const errors = validateRegistration(body);
  if (errors.length > 0) {
    return res.status(400).json({ error: 'Invalid registration.', details: errors });
  }

  const user = await createUser(body);
  if (!user) {
    return res.status(409).json({ error: 'An account with this email already exists.' });
  }

  return res.status(201).json({
    data: {
      token: createSession(user.id),
      user: publicProfile(user),
    },
  });
}

async function login(req, res) {
  const body = req.body && typeof req.body === 'object' ? req.body : {};
  if (body.humanVerified !== true) {
    return res.status(400).json({ error: 'Human verification is required.' });
  }

  if (
    typeof body.email !== 'string' ||
    typeof body.password !== 'string' ||
    body.password.length === 0
  ) {
    return res.status(400).json({ error: 'Email and password are required.' });
  }

  const user = await findUserByEmail(body.email);
  if (!user || !verifyPassword(user, body.password)) {
    return res.status(401).json({ error: 'Email or password is incorrect.' });
  }

  return res.json({
    data: {
      token: createSession(user.id),
      user: publicProfile(user),
    },
  });
}

function logout(req, res) {
  revokeSession(req.authToken);
  return res.json({ data: { signedOut: true } });
}

function getCurrentUser(req, res) {
  return res.json({ data: publicProfile(req.authUser) });
}

module.exports = { getCurrentUser, login, logout, register };
