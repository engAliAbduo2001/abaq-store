const { createHash, randomBytes, randomUUID } = require('node:crypto');
const { database } = require('../database');

const intentLifetimeMs = 30 * 60 * 1000;

function paymentProvider() {
  if (process.env.ABAQ_PAYMENT_MODE === 'simulation') {
    if (
      process.env.NODE_ENV === 'production' &&
      process.env.ABAQ_ALLOW_SIMULATED_PAYMENTS !== 'true'
    ) {
      throw new Error('Simulated payments are disabled in production.');
    }
    return 'simulation';
  }
  if (process.env.STRIPE_SECRET_KEY) return 'stripe';
  if (process.env.ABAQ_PAYMENT_MODE === 'stripe') {
    throw new Error('Stripe payment mode requires STRIPE_SECRET_KEY.');
  }
  if (
    process.env.NODE_ENV === 'production' &&
    process.env.ABAQ_ALLOW_SIMULATED_PAYMENTS !== 'true'
  ) {
    throw new Error(
      'Configure STRIPE_SECRET_KEY before accepting production payments.',
    );
  }
  return 'simulation';
}

function secretHash(secret) {
  return createHash('sha256').update(secret).digest('hex');
}

async function stripeRequest(path, { method = 'POST', body } = {}) {
  const secretKey = process.env.STRIPE_SECRET_KEY;
  if (!secretKey) {
    throw new Error('Stripe payment mode requires STRIPE_SECRET_KEY.');
  }

  const response = await fetch(`https://api.stripe.com/v1/${path}`, {
    method,
    headers: {
      authorization: `Bearer ${secretKey}`,
      ...(body ? { 'content-type': 'application/x-www-form-urlencoded' } : {}),
    },
    body,
    signal: AbortSignal.timeout(10000),
  });
  const payload = await response.json();
  if (!response.ok) {
    throw new Error(
      `Stripe request failed (${response.status}): ${
        payload.error?.message || 'Payment provider error.'
      }`,
    );
  }
  return payload;
}

async function createPaymentIntent({ cart, totals, userId }) {
  const provider = paymentProvider();
  const now = Date.now();
  const internalId = `pi_${randomUUID().replaceAll('-', '')}`;
  let paymentIntentId = internalId;
  let clientSecret;
  let status = 'requires_payment_method';

  if (provider === 'stripe') {
    const body = new URLSearchParams({
      amount: String(totals.totalCents),
      currency: 'usd',
      'automatic_payment_methods[enabled]': 'true',
      'metadata[abaq_intent_id]': internalId,
      'metadata[cart_hash]': createHash('sha256')
        .update(
          JSON.stringify({
            items: cart.items
              .map(({ product, quantity }) => ({
                perfumeId: product.id,
                quantity,
              }))
              .sort((left, right) =>
                left.perfumeId.localeCompare(right.perfumeId),
              ),
            couponCode: totals.couponCode,
            amountCents: totals.totalCents,
          }),
        )
        .digest('hex'),
    });
    const stripeIntent = await stripeRequest('payment_intents', { body });
    if (
      typeof stripeIntent.id !== 'string' ||
      typeof stripeIntent.client_secret !== 'string'
    ) {
      throw new Error('Stripe returned an invalid payment intent.');
    }
    paymentIntentId = stripeIntent.id;
    clientSecret = stripeIntent.client_secret;
    status = stripeIntent.status || status;
  } else {
    clientSecret = `sim_secret_${randomBytes(32).toString('base64url')}`;
  }

  const paymentIntent = {
    id: paymentIntentId,
    provider,
    clientSecretHash: provider === 'simulation' ? secretHash(clientSecret) : null,
    userId: userId || null,
    items: cart.items.map(({ product, quantity }) => ({
      perfumeId: product.id,
      quantity,
    })),
    couponCode: totals.couponCode,
    subtotalCents: totals.subtotalCents,
    discountCents: totals.discountCents,
    shippingCents: totals.shippingCents,
    amountCents: totals.totalCents,
    currency: 'usd',
    status,
    createdAt: new Date(now).toISOString(),
    expiresAt: now + intentLifetimeMs,
    consumedAt: null,
  };
  const savedIntent = await database.createPaymentIntent(paymentIntent);
  if (!savedIntent) {
    throw new Error('Could not save the payment intent.');
  }

  return {
    paymentIntentId,
    clientSecret,
    provider,
    amount: totals.totalCents / 100,
    currency: 'USD',
    quote: {
      couponCode: totals.couponCode,
      subtotal: totals.subtotalCents / 100,
      discount: totals.discountCents / 100,
      shipping: totals.shippingCents / 100,
      totalAmount: totals.totalCents / 100,
    },
  };
}

async function confirmPaymentIntent({ intent, clientSecret }) {
  if (intent.expiresAt <= Date.now()) {
    return { error: 'Payment session expired. Start checkout again.' };
  }
  if (intent.consumedAt) {
    return { error: 'This payment session has already been used.' };
  }

  if (intent.provider === 'simulation') {
    if (
      process.env.NODE_ENV === 'production' &&
      process.env.ABAQ_ALLOW_SIMULATED_PAYMENTS !== 'true'
    ) {
      return { error: 'Simulated payments are disabled in production.' };
    }
    if (
      typeof clientSecret !== 'string' ||
      secretHash(clientSecret) !== intent.clientSecretHash
    ) {
      return { error: 'Payment session is invalid.' };
    }
  } else {
    const stripeIntent = await stripeRequest(
      `payment_intents/${encodeURIComponent(intent.id)}`,
      { method: 'GET' },
    );
    if (
      stripeIntent.status !== 'succeeded' ||
      stripeIntent.amount_received !== intent.amountCents ||
      stripeIntent.currency !== intent.currency
    ) {
      return { error: 'Payment has not been completed.' };
    }
  }

  if (intent.status !== 'succeeded') {
    const updatedIntent = await database.updatePaymentIntentStatus(
      intent.id,
      'succeeded',
    );
    if (!updatedIntent) {
      return { error: 'Payment session is no longer available.' };
    }
  }
  return { paymentIntentId: intent.id, status: 'succeeded' };
}

module.exports = {
  confirmPaymentIntent,
  createPaymentIntent,
  paymentProvider,
};
