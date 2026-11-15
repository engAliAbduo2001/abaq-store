const { database } = require('../database');
const { calculateTotals, validateCart } = require('../services/pricing');
const {
  confirmPaymentIntent,
  createPaymentIntent,
  paymentProvider,
} = require('../services/paymentService');

async function createIntent(req, res) {
  const cart = await validateCart(req.body?.items);
  if (cart.errors.length > 0) {
    return res.status(400).json({
      error: 'Invalid cart.',
      details: cart.errors,
    });
  }
  const totals = await calculateTotals(cart.subtotalCents, req.body?.couponCode);
  if (totals.error) {
    return res.status(400).json({ error: totals.error });
  }

  try {
    const intent = await createPaymentIntent({
      cart,
      totals,
      userId: req.authUser?.id,
    });
    return res.status(201).json({ data: intent });
  } catch (error) {
    console.error('Could not create payment intent.', error);
    if (
      process.env.NODE_ENV === 'production' &&
      !process.env.STRIPE_SECRET_KEY &&
      process.env.ABAQ_ALLOW_SIMULATED_PAYMENTS !== 'true'
    ) {
      return res.status(503).json({
        error: 'Card payments are not configured on this server.',
      });
    }
    if (error.message.includes('requires STRIPE_SECRET_KEY')) {
      return res.status(503).json({
        error: 'Card payments are not configured on this server.',
      });
    }
    return res.status(502).json({
      error: 'The payment provider could not start a checkout session.',
    });
  }
}

async function confirmIntent(req, res) {
  const { paymentIntentId, clientSecret } = req.body || {};
  if (typeof paymentIntentId !== 'string' || paymentIntentId.length === 0) {
    return res.status(400).json({ error: 'paymentIntentId is required.' });
  }

  const intent = await database.getPaymentIntentById(paymentIntentId);
  if (!intent || intent.userId !== (req.authUser?.id || null)) {
    return res.status(404).json({ error: 'Payment session not found.' });
  }

  if (
    intent.provider === 'simulation' &&
    typeof clientSecret !== 'string'
  ) {
    return res.status(400).json({
      error: 'clientSecret is required to confirm a simulated payment.',
    });
  }
  if (intent.provider === 'stripe' && paymentProvider() !== 'stripe') {
    return res.status(503).json({
      error: 'Stripe verification is not configured on this server.',
    });
  }

  const result = await confirmPaymentIntent({ intent, clientSecret });
  if (result.error) {
    return res.status(409).json({ error: result.error });
  }
  return res.json({ data: result });
}

module.exports = { confirmIntent, createIntent };
