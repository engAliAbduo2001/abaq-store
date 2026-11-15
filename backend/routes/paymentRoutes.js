const express = require('express');
const {
  confirmIntent,
  createIntent,
} = require('../controllers/paymentController');
const asyncHandler = require('../middleware/asyncHandler');
const { optionalAuth } = require('../middleware/auth');

const router = express.Router();

router.post('/create-intent', optionalAuth, asyncHandler(createIntent));
router.post('/confirm', optionalAuth, asyncHandler(confirmIntent));

module.exports = router;
