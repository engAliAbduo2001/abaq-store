const { database } = require('../database');

async function validateCart(items) {
  const errors = [];
  const validatedItems = [];
  if (!Array.isArray(items) || items.length === 0) {
    return {
      errors: ['items must be a non-empty array.'],
      items: validatedItems,
      subtotalCents: 0,
    };
  }

  const products = await database.getProducts();
  const productsById = new Map(products.map((product) => [product.id, product]));
  let subtotalCents = 0;
  items.forEach((item, index) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      errors.push(`items[${index}] must include perfumeId and quantity.`);
      return;
    }

    const product = productsById.get(item.perfumeId);
    if (!product) {
      errors.push(`items[${index}].perfumeId is not available.`);
    }
    if (!Number.isInteger(item.quantity) || item.quantity < 1) {
      errors.push(`items[${index}].quantity must be a positive integer.`);
    }
    if (product && Number.isInteger(item.quantity) && item.quantity > 0) {
      const unitPriceCents = Math.round(product.price * 100);
      subtotalCents += unitPriceCents * item.quantity;
      validatedItems.push({
        product,
        quantity: item.quantity,
        unitPriceCents,
      });
    }
  });

  return { errors, items: validatedItems, subtotalCents };
}

async function calculateTotals(subtotalCents, rawCouponCode) {
  if (
    rawCouponCode !== undefined &&
    rawCouponCode !== null &&
    typeof rawCouponCode !== 'string'
  ) {
    return { error: 'couponCode must be a string.' };
  }
  const couponCode =
    typeof rawCouponCode === 'string' && rawCouponCode.trim()
      ? rawCouponCode.trim().toUpperCase()
      : null;
  let coupon = null;
  let discountCents = 0;

  if (couponCode) {
    coupon = await database.getCouponByCode(couponCode);
    if (
      !coupon ||
      coupon.active !== true ||
      coupon.discountType !== 'percentage' ||
      !Number.isFinite(coupon.discountValue) ||
      coupon.discountValue <= 0 ||
      coupon.discountValue > 100
    ) {
      return { error: 'This promo code is invalid or inactive.' };
    }
    discountCents = Math.min(
      subtotalCents,
      Math.round((subtotalCents * coupon.discountValue) / 100),
    );
  }

  const shippingCents = subtotalCents > 30000 ? 0 : 1000;
  return {
    couponCode,
    discountCents,
    shippingCents,
    subtotalCents,
    totalCents: subtotalCents - discountCents + shippingCents,
  };
}

module.exports = { calculateTotals, validateCart };
