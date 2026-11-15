const express = require('express');
const {
  getCurrentUser,
  login,
  logout,
  register,
} = require('../controllers/authController');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.post('/register', asyncHandler(register));
router.post('/login', asyncHandler(login));
router.get('/me', requireAuth, asyncHandler(getCurrentUser));
router.post('/logout', requireAuth, logout);

module.exports = router;
