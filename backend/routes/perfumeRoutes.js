const express = require('express');
const {
  getProductById,
  getProducts,
} = require('../controllers/perfumeController');
const asyncHandler = require('../middleware/asyncHandler');

const router = express.Router();

router.get('/', asyncHandler(getProducts));
router.get('/:id', asyncHandler(getProductById));

module.exports = router;
