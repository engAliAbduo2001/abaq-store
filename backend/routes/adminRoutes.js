const express = require('express');
const {
  createProduct,
  deleteProduct,
  getOrders,
  updateOrderStatus,
  updateProduct,
} = require('../controllers/adminController');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAdmin, requireAuth } = require('../middleware/auth');

const router = express.Router();

router.use(requireAuth, requireAdmin);

router.post('/products', asyncHandler(createProduct));
router.put('/products/:id', asyncHandler(updateProduct));
router.delete('/products/:id', asyncHandler(deleteProduct));
router.get('/orders', asyncHandler(getOrders));
router.put('/orders/:id/status', asyncHandler(updateOrderStatus));

module.exports = router;
