const { randomBytes, randomUUID } = require('node:crypto');
const { database } = require('../database');
const { calculateTotals, validateCart } = require('../services/pricing');

async function createInvoiceNumber(createdAt) {
  let invoiceNumber;
  do {
    const suffix = randomBytes(2).toString('hex').toUpperCase();
    invoiceNumber = `ABQ-${createdAt.getUTCFullYear()}-${suffix}`;
  } while (await database.getOrderByInvoiceNumber(invoiceNumber));
  return invoiceNumber;
}

async function createOrder(req, res) {
  const {
    customer,
    items,
    paymentMethod,
    totalAmount,
    couponCode,
    paymentIntentId,
  } = req.body || {};
  const errors = [];

  if (!customer || typeof customer !== 'object' || Array.isArray(customer)) {
    errors.push('customer must include name, phone, and address.');
  } else {
    if (typeof customer.name !== 'string' || customer.name.trim().length < 2) {
      errors.push('customer.name must be at least 2 characters.');
    }
    if (typeof customer.phone !== 'string') {
      errors.push('customer.phone must be a valid phone number.');
    } else {
      const digits = customer.phone.replace(/\D/g, '');
      if (digits.length < 7 || digits.length > 15) {
        errors.push('customer.phone must contain 7 to 15 digits.');
      }
    }
    if (
      typeof customer.address !== 'string' ||
      customer.address.trim().length < 5
    ) {
      errors.push('customer.address must be at least 5 characters.');
    }
  }

  if (!Array.isArray(items) || items.length === 0) {
    errors.push('items must be a non-empty array.');
  }

  if (!['COD', 'Card'].includes(paymentMethod)) {
    errors.push('paymentMethod must be COD or Card.');
  }

  const cart = await validateCart(items);
  errors.push(...cart.errors);
  const totals = await calculateTotals(cart.subtotalCents, couponCode);
  if (totals.error) errors.push(totals.error);

  if (
    typeof totalAmount !== 'number' ||
    !Number.isFinite(totalAmount) ||
    totalAmount <= 0
  ) {
    errors.push('totalAmount must be a positive number.');
  } else if (
    !totals.error &&
    Math.round(totalAmount * 100) !== totals.totalCents
  ) {
    errors.push('totalAmount does not match the items and shipping.');
  }

  let paymentIntent = null;
  if (paymentMethod === 'Card') {
    if (typeof paymentIntentId !== 'string' || paymentIntentId.length === 0) {
      errors.push('A confirmed paymentIntentId is required for card orders.');
    } else {
      paymentIntent = await database.getPaymentIntentById(paymentIntentId);
      if (!paymentIntent || paymentIntent.status !== 'succeeded') {
        errors.push('The card payment has not been confirmed.');
      }
    }
  } else if (paymentIntentId !== undefined && paymentIntentId !== null) {
    errors.push('paymentIntentId is only allowed for card orders.');
  }

  if (errors.length > 0) {
    return res.status(400).json({ error: 'Invalid order.', details: errors });
  }

  const subtotal = totals.subtotalCents / 100;
  const discount = totals.discountCents / 100;
  const shipping = totals.shippingCents / 100;
  const calculatedTotal = totals.totalCents / 100;
  const createdAt = new Date();
  const order = {
    id: randomUUID(),
    invoiceNumber: await createInvoiceNumber(createdAt),
    createdAt: createdAt.toISOString(),
    userId: req.authUser ? req.authUser.id : null,
    customer: {
      name: customer.name.trim(),
      phone: customer.phone.trim(),
      address: customer.address.trim(),
    },
    items: cart.items.map(({ product, quantity, unitPriceCents }) => ({
      perfumeId: product.id,
      name: product.name,
      quantity,
      unitPrice: unitPriceCents / 100,
      lineTotal: (unitPriceCents * quantity) / 100,
    })),
    paymentMethod,
    paymentIntentId: paymentIntentId || null,
    paymentProvider: paymentIntent?.provider || null,
    couponCode: totals.couponCode,
    subtotal,
    discount,
    shipping,
    totalAmount: calculatedTotal,
    currency: 'USD',
    status: 'Pending',
    trackingNumber: `ABQ-TRK-${randomBytes(4).toString('hex').toUpperCase()}`,
  };

  const saved = await database.createOrder(order, paymentIntentId);
  if (!saved) {
    if (paymentIntentId) {
      return res.status(409).json({
        error: 'Payment session is invalid, mismatched, or already used.',
      });
    }
    order.invoiceNumber = await createInvoiceNumber(createdAt);
    const retrySaved = await database.createOrder(order);
    if (!retrySaved) {
      throw new Error('Could not generate a unique invoice number.');
    }
  }
  return res.status(201).json({ data: order });
}

async function getOrderByInvoiceNumber(req, res) {
  const order = await database.getOrderByInvoiceNumber(req.params.invoiceNumber);
  if (!order || order.userId !== req.authUser.id) {
    return res.status(404).json({ error: 'Invoice not found.' });
  }
  return res.json({ data: order });
}

function listOrdersForUser(userId) {
  return database.getOrdersForUser(userId);
}

module.exports = {
  createOrder,
  getOrderByInvoiceNumber,
  listOrdersForUser,
};
