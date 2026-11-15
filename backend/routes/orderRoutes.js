const express = require('express');
const {
  createOrder,
  getOrderByInvoiceNumber,
} = require('../controllers/orderController');
const asyncHandler = require('../middleware/asyncHandler');
const { optionalAuth, requireAuth } = require('../middleware/auth');

const router = express.Router();

router.post('/', optionalAuth, asyncHandler(createOrder));
router.get(
  '/:invoiceNumber',
  requireAuth,
  asyncHandler(getOrderByInvoiceNumber),
);

module.exports = router;
