const { calculateTotals, validateCart } = require('../services/pricing');

async function validateCoupon(req, res) {
  const cart = await validateCart(req.body?.items);
  if (cart.errors.length > 0) {
    return res.status(400).json({
      error: 'Invalid cart.',
      details: cart.errors,
    });
  }
  const totals = await calculateTotals(cart.subtotalCents, req.body?.code);
  if (totals.error) {
    return res.status(400).json({ error: totals.error });
  }
  if (!totals.couponCode) {
    return res.status(400).json({ error: 'Enter a promo code to validate.' });
  }

  return res.json({
    data: {
      couponCode: totals.couponCode,
      subtotal: totals.subtotalCents / 100,
      discount: totals.discountCents / 100,
      shipping: totals.shippingCents / 100,
      totalAmount: totals.totalCents / 100,
    },
  });
}

module.exports = { validateCoupon };
