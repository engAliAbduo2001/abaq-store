const express = require('express');
const {
  getUserOrders,
  getUserWishlist,
  saveUserWishlist,
} = require('../controllers/userController');
const asyncHandler = require('../middleware/asyncHandler');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();

router.get('/:userId/orders', requireAuth, asyncHandler(getUserOrders));
router.get('/:userId/wishlist', requireAuth, asyncHandler(getUserWishlist));
router.put('/:userId/wishlist', requireAuth, asyncHandler(saveUserWishlist));

module.exports = router;
