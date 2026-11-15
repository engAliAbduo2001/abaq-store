const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const { rm } = require('node:fs/promises');
const os = require('node:os');
const path = require('node:path');
const { after, before, test } = require('node:test');

const databasePath = path.join(os.tmpdir(), `abaq-api-${randomUUID()}.json`);
process.env.ABAQ_DATABASE_PATH = databasePath;
const { database, JsonDatabase } = require('../database');
const app = require('../server');

let server;
let baseUrl;

before(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
  await rm(databasePath, { force: true });
});

test('perfume listing supports category and search filters', async () => {
  const response = await fetch(
    `${baseUrl}/api/perfumes?category=oud&search=royale`,
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.count, 1);
  assert.equal(body.data[0].id, 'oud-royale');
});

test('CORS allows a configured frontend origin', async () => {
  const configuredOrigins = (process.env.CORS_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  const origin =
    configuredOrigins.length === 0 || configuredOrigins.includes('*')
      ? 'https://shop.example.com'
      : configuredOrigins[0];
  const response = await fetch(`${baseUrl}/health`, {
    headers: { origin },
  });

  assert.equal(response.headers.get('access-control-allow-origin'), origin);
});

test('perfume details return 404 for an unknown ID', async () => {
  const response = await fetch(`${baseUrl}/api/perfumes/not-a-product`);
  assert.equal(response.status, 404);
});

test('products expose the expanded schema while perfume routes stay compatible', async () => {
  const response = await fetch(
    `${baseUrl}/api/products?category=oud&search=royale`,
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.count, 1);
  assert.equal(body.data[0].id, 'oud-royale');
  assert.equal(body.data[0].image, body.data[0].imageUrl);
  assert.equal(typeof body.data[0].rating, 'number');
  assert.equal(body.data[0].isBestseller, true);
  assert.equal(body.data[0].isNew, false);

  const detailResponse = await fetch(
    `${baseUrl}/api/products/${body.data[0].id}`,
  );
  assert.equal(detailResponse.status, 200);
  assert.equal((await detailResponse.json()).data.id, 'oud-royale');

  const legacyResponse = await fetch(
    `${baseUrl}/api/perfumes?category=oud&search=royale`,
  );
  const legacyBody = await legacyResponse.json();
  assert.equal(legacyResponse.status, 200);
  assert.deepEqual(legacyBody.data, body.data);
});

test('orders calculate shipping, create an invoice, and can be retrieved', async () => {
  const order = {
    customer: {
      name: 'Sam Example',
      phone: '+1 555 010 1234',
      address: '123 Example Street, New York',
    },
    items: [{ perfumeId: 'oud-royale', quantity: 1 }],
    paymentMethod: 'COD',
    totalAmount: 255,
  };
  const validResponse = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(order),
  });
  const validBody = await validResponse.json();

  assert.equal(validResponse.status, 201);
  assert.ok(validBody.data.id);
  assert.match(validBody.data.invoiceNumber, /^ABQ-\d{4}-[A-F0-9]{4}$/);
  assert.equal(validBody.data.paymentMethod, 'COD');
  assert.equal(validBody.data.subtotal, 245);
  assert.equal(validBody.data.shipping, 10);
  assert.equal(validBody.data.totalAmount, 255);
  assert.equal(validBody.data.userId, null);
  assert.equal(validBody.data.status, 'Pending');
  assert.match(validBody.data.trackingNumber, /^ABQ-TRK-[A-F0-9]{8}$/);

  const invoiceResponse = await fetch(
    `${baseUrl}/api/orders/${validBody.data.invoiceNumber}`,
  );
  assert.equal(invoiceResponse.status, 401);

  const freeShippingResponse = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      ...order,
      items: [{ perfumeId: 'oud-royale', quantity: 2 }],
      paymentMethod: 'COD',
      totalAmount: 490,
    }),
  });
  const freeShippingBody = await freeShippingResponse.json();
  assert.equal(freeShippingResponse.status, 201);
  assert.equal(freeShippingBody.data.shipping, 0);
  assert.notEqual(
    freeShippingBody.data.invoiceNumber,
    validBody.data.invoiceNumber,
  );

  const missingInvoiceResponse = await fetch(
    `${baseUrl}/api/orders/ABQ-2026-MISSING`,
  );
  assert.equal(missingInvoiceResponse.status, 401);

  const invalidResponse = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ ...order, totalAmount: 1, paymentMethod: 'Crypto' }),
  });
  assert.equal(invalidResponse.status, 400);
});

test('coupons recalculate totals and card orders require a confirmed one-use payment intent', async () => {
  const cart = [{ perfumeId: 'oud-royale', quantity: 1 }];
  const quoteResponse = await fetch(`${baseUrl}/api/coupons/validate`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ code: 'abaq10', items: cart }),
  });
  const quote = (await quoteResponse.json()).data;
  assert.equal(quoteResponse.status, 200);
  assert.equal(quote.couponCode, 'ABAQ10');
  assert.equal(quote.subtotal, 245);
  assert.equal(quote.discount, 24.5);
  assert.equal(quote.shipping, 10);
  assert.equal(quote.totalAmount, 230.5);

  const luxuryQuoteResponse = await fetch(
    `${baseUrl}/api/coupons/validate`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ code: 'LUXURY20', items: cart }),
    },
  );
  const luxuryQuote = (await luxuryQuoteResponse.json()).data;
  assert.equal(luxuryQuoteResponse.status, 200);
  assert.equal(luxuryQuote.discount, 49);
  assert.equal(luxuryQuote.totalAmount, 206);

  const invalidCouponResponse = await fetch(
    `${baseUrl}/api/coupons/validate`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ code: 'UNKNOWN', items: cart }),
    },
  );
  assert.equal(invalidCouponResponse.status, 400);

  const intentResponse = await fetch(
    `${baseUrl}/api/payment/create-intent`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ items: cart, couponCode: 'ABAQ10' }),
    },
  );
  const intent = (await intentResponse.json()).data;
  assert.equal(intentResponse.status, 201);
  assert.equal(intent.provider, 'simulation');
  assert.equal(intent.quote.totalAmount, 230.5);

  const invalidConfirmation = await fetch(
    `${baseUrl}/api/payment/confirm`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        paymentIntentId: intent.paymentIntentId,
        clientSecret: 'wrong-secret',
      }),
    },
  );
  assert.equal(invalidConfirmation.status, 409);

  const confirmation = await fetch(`${baseUrl}/api/payment/confirm`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      paymentIntentId: intent.paymentIntentId,
      clientSecret: intent.clientSecret,
    }),
  });
  assert.equal(confirmation.status, 200);

  const cardOrder = {
    customer: {
      name: 'Sam Example',
      phone: '+1 555 010 1234',
      address: '123 Example Street, New York',
    },
    items: cart,
    paymentMethod: 'Card',
    totalAmount: 230.5,
    couponCode: 'ABAQ10',
    paymentIntentId: intent.paymentIntentId,
  };
  const missingIntentResponse = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ ...cardOrder, paymentIntentId: undefined }),
  });
  assert.equal(missingIntentResponse.status, 400);

  const mismatchedAmountResponse = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ ...cardOrder, totalAmount: 255 }),
  });
  assert.equal(mismatchedAmountResponse.status, 400);

  const orderResponse = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(cardOrder),
  });
  const order = (await orderResponse.json()).data;
  assert.equal(orderResponse.status, 201);
  assert.equal(order.discount, 24.5);
  assert.equal(order.couponCode, 'ABAQ10');
  assert.equal(order.totalAmount, 230.5);
  assert.equal(order.paymentProvider, 'simulation');

  const replayResponse = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(cardOrder),
  });
  assert.equal(replayResponse.status, 409);

  const previousEnvironment = {
    nodeEnv: process.env.NODE_ENV,
    paymentMode: process.env.ABAQ_PAYMENT_MODE,
    allowSimulation: process.env.ABAQ_ALLOW_SIMULATED_PAYMENTS,
    stripeSecret: process.env.STRIPE_SECRET_KEY,
  };
  process.env.NODE_ENV = 'production';
  delete process.env.ABAQ_PAYMENT_MODE;
  delete process.env.ABAQ_ALLOW_SIMULATED_PAYMENTS;
  delete process.env.STRIPE_SECRET_KEY;
  try {
    const unconfiguredIntentResponse = await fetch(
      `${baseUrl}/api/payment/create-intent`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ items: cart }),
      },
    );
    assert.equal(unconfiguredIntentResponse.status, 503);
  } finally {
    if (previousEnvironment.nodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousEnvironment.nodeEnv;
    if (previousEnvironment.paymentMode === undefined) {
      delete process.env.ABAQ_PAYMENT_MODE;
    } else {
      process.env.ABAQ_PAYMENT_MODE = previousEnvironment.paymentMode;
    }
    if (previousEnvironment.allowSimulation === undefined) {
      delete process.env.ABAQ_ALLOW_SIMULATED_PAYMENTS;
    } else {
      process.env.ABAQ_ALLOW_SIMULATED_PAYMENTS =
        previousEnvironment.allowSimulation;
    }
    if (previousEnvironment.stripeSecret === undefined) {
      delete process.env.STRIPE_SECRET_KEY;
    } else {
      process.env.STRIPE_SECRET_KEY = previousEnvironment.stripeSecret;
    }
  }
});

test('demo account login returns a session and a safe profile', async () => {
  const missingVerification = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ email: 'ali@abaq.com', password: '123456' }),
  });
  assert.equal(missingVerification.status, 400);

  const falseVerification = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: 'ali@abaq.com',
      password: '123456',
      humanVerified: false,
    }),
  });
  assert.equal(falseVerification.status, 400);

  const response = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: 'ali@abaq.com',
      password: '123456',
      humanVerified: true,
    }),
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.ok(body.data.token);
  assert.equal(body.data.user.email, 'ali@abaq.com');
  assert.equal(body.data.user.name, 'Ali Abaq');
  assert.equal(body.data.user.role, 'customer');
  assert.equal(Object.hasOwn(body.data.user, 'passwordHash'), false);

  const currentUserResponse = await fetch(`${baseUrl}/api/auth/me`, {
    headers: { authorization: `Bearer ${body.data.token}` },
  });
  assert.equal(currentUserResponse.status, 200);
  assert.equal((await currentUserResponse.json()).data.id, body.data.user.id);

  const unauthenticatedUserResponse = await fetch(`${baseUrl}/api/auth/me`);
  assert.equal(unauthenticatedUserResponse.status, 401);

  const badLogin = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: 'ali@abaq.com',
      password: 'wrong-password',
      humanVerified: true,
    }),
  });
  assert.equal(badLogin.status, 401);
});

test('registration, authenticated orders, ownership, and logout work', async () => {
  const registration = await fetch(`${baseUrl}/api/auth/register`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      name: 'Nora Example',
      email: `nora-${Date.now()}@example.com`,
      phone: '+1 555 010 1234',
      address: '456 Example Avenue, New York',
      password: 'secret123',
    }),
  });
  const session = (await registration.json()).data;
  assert.equal(registration.status, 201);
  assert.ok(session.token);

  const orderResponse = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${session.token}`,
    },
    body: JSON.stringify({
      customer: {
        name: session.user.name,
        phone: session.user.phone,
        address: session.user.address,
      },
      items: [{ perfumeId: 'desert-rose', quantity: 1 }],
      paymentMethod: 'COD',
      totalAmount: 205,
    }),
  });
  const savedOrder = (await orderResponse.json()).data;
  assert.equal(orderResponse.status, 201);
  assert.equal(savedOrder.userId, session.user.id);

  const historyResponse = await fetch(
    `${baseUrl}/api/users/${session.user.id}/orders`,
    { headers: { authorization: `Bearer ${session.token}` } },
  );
  const history = await historyResponse.json();
  assert.equal(historyResponse.status, 200);
  assert.equal(history.data.length, 1);
  assert.equal(history.data[0].invoiceNumber, savedOrder.invoiceNumber);

  const invoiceResponse = await fetch(
    `${baseUrl}/api/orders/${savedOrder.invoiceNumber}`,
    { headers: { authorization: `Bearer ${session.token}` } },
  );
  const invoice = await invoiceResponse.json();
  assert.equal(invoiceResponse.status, 200);
  assert.equal(invoice.data.customer.name, 'Nora Example');
  assert.equal(invoice.data.items[0].unitPrice, 195);

  const missingInvoiceResponse = await fetch(
    `${baseUrl}/api/orders/ABQ-2026-MISSING`,
    { headers: { authorization: `Bearer ${session.token}` } },
  );
  assert.equal(missingInvoiceResponse.status, 404);

  const otherUserResponse = await fetch(
    `${baseUrl}/api/users/not-${session.user.id}/orders`,
    { headers: { authorization: `Bearer ${session.token}` } },
  );
  assert.equal(otherUserResponse.status, 403);

  const otherWishlistResponse = await fetch(
    `${baseUrl}/api/users/not-${session.user.id}/wishlist`,
    { headers: { authorization: `Bearer ${session.token}` } },
  );
  assert.equal(otherWishlistResponse.status, 403);

  const invalidWishlistResponse = await fetch(
    `${baseUrl}/api/users/${session.user.id}/wishlist`,
    {
      method: 'PUT',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${session.token}`,
      },
      body: JSON.stringify({ productIds: ['not-a-product'] }),
    },
  );
  assert.equal(invalidWishlistResponse.status, 400);

  const saveWishlistResponse = await fetch(
    `${baseUrl}/api/users/${session.user.id}/wishlist`,
    {
      method: 'PUT',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${session.token}`,
      },
      body: JSON.stringify({ productIds: ['desert-rose', 'oud-royale'] }),
    },
  );
  assert.equal(saveWishlistResponse.status, 200);
  assert.deepEqual(
    (await saveWishlistResponse.json()).data,
    ['desert-rose', 'oud-royale'],
  );

  const wishlistResponse = await fetch(
    `${baseUrl}/api/users/${session.user.id}/wishlist`,
    { headers: { authorization: `Bearer ${session.token}` } },
  );
  assert.equal(wishlistResponse.status, 200);
  assert.deepEqual(
    (await wishlistResponse.json()).data,
    ['desert-rose', 'oud-royale'],
  );

  const reopenedDatabase = new JsonDatabase({ filePath: database.filePath });
  await reopenedDatabase.initialize();
  assert.equal(
    (await reopenedDatabase.getUserById(session.user.id)).email,
    session.user.email,
  );
  assert.ok(
    (await reopenedDatabase.getProducts()).some(
      (product) => product.id === 'oud-royale',
    ),
  );
  assert.deepEqual(
    await reopenedDatabase.getWishlist(session.user.id),
    ['desert-rose', 'oud-royale'],
  );
  assert.equal(
    (await reopenedDatabase.getOrdersForUser(session.user.id))[0].id,
    savedOrder.id,
  );

  const logoutResponse = await fetch(`${baseUrl}/api/auth/logout`, {
    method: 'POST',
    headers: { authorization: `Bearer ${session.token}` },
  });
  assert.equal(logoutResponse.status, 200);

  const expiredHistoryResponse = await fetch(
    `${baseUrl}/api/users/${session.user.id}/orders`,
    { headers: { authorization: `Bearer ${session.token}` } },
  );
  assert.equal(expiredHistoryResponse.status, 401);
});

test('admin APIs enforce roles and manage products and order status', async () => {
  const unauthenticatedResponse = await fetch(`${baseUrl}/api/admin/orders`);
  assert.equal(unauthenticatedResponse.status, 401);

  const customerLogin = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: 'ali@abaq.com',
      password: '123456',
      humanVerified: true,
    }),
  });
  const customerSession = (await customerLogin.json()).data;
  assert.equal(customerSession.user.role, 'customer');
  const forbiddenResponse = await fetch(`${baseUrl}/api/admin/orders`, {
    headers: { authorization: `Bearer ${customerSession.token}` },
  });
  assert.equal(forbiddenResponse.status, 403);

  const adminLogin = await fetch(`${baseUrl}/api/auth/login`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      email: 'admin@abaq.com',
      password: '123456',
      humanVerified: true,
    }),
  });
  const adminSession = (await adminLogin.json()).data;
  assert.equal(adminLogin.status, 200);
  assert.equal(adminSession.user.role, 'admin');

  const productInput = {
    name: 'Velvet Test',
    brand: 'Abaq Atelier',
    category: 'Oriental',
    description: 'A refined blend of amber, rose, and soft woods.',
    notes: ['amber', 'rose', 'woods'],
    price: 180,
    imageUrl: 'https://example.com/velvet-test.jpg',
    rating: 4.6,
    isBestseller: false,
    isNew: true,
  };
  const createProductResponse = await fetch(`${baseUrl}/api/admin/products`, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${adminSession.token}`,
    },
    body: JSON.stringify(productInput),
  });
  const createdProduct = (await createProductResponse.json()).data;
  assert.equal(createProductResponse.status, 201);
  assert.match(createdProduct.id, /^velvet-test-[a-f0-9]{8}$/);
  assert.equal(createdProduct.image, productInput.imageUrl);
  assert.equal(createdProduct.isNew, true);

  const updateProductResponse = await fetch(
    `${baseUrl}/api/admin/products/${createdProduct.id}`,
    {
      method: 'PUT',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${adminSession.token}`,
      },
      body: JSON.stringify({ price: 195 }),
    },
  );
  assert.equal(updateProductResponse.status, 200);
  assert.equal((await updateProductResponse.json()).data.price, 195);

  const invalidProductResponse = await fetch(
    `${baseUrl}/api/admin/products`,
    {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${adminSession.token}`,
      },
      body: JSON.stringify({ ...productInput, price: -1 }),
    },
  );
  assert.equal(invalidProductResponse.status, 400);

  const orderResponse = await fetch(`${baseUrl}/api/orders`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      customer: {
        name: 'Admin Test',
        phone: '+1 555 010 9999',
        address: '789 Admin Street',
      },
      items: [{ perfumeId: 'oud-royale', quantity: 1 }],
      paymentMethod: 'COD',
      totalAmount: 255,
    }),
  });
  const order = (await orderResponse.json()).data;
  const ordersResponse = await fetch(`${baseUrl}/api/admin/orders`, {
    headers: { authorization: `Bearer ${adminSession.token}` },
  });
  const orders = (await ordersResponse.json()).data;
  assert.equal(ordersResponse.status, 200);
  assert.ok(orders.some((entry) => entry.id === order.id));

  const updateStatusResponse = await fetch(
    `${baseUrl}/api/admin/orders/${order.id}/status`,
    {
      method: 'PUT',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${adminSession.token}`,
      },
      body: JSON.stringify({ status: 'Shipped' }),
    },
  );
  assert.equal(updateStatusResponse.status, 200);
  assert.equal((await updateStatusResponse.json()).data.status, 'Shipped');

  const invalidStatusResponse = await fetch(
    `${baseUrl}/api/admin/orders/${order.id}/status`,
    {
      method: 'PUT',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${adminSession.token}`,
      },
      body: JSON.stringify({ status: 'Cancelled' }),
    },
  );
  assert.equal(invalidStatusResponse.status, 400);

  const deleteProductResponse = await fetch(
    `${baseUrl}/api/admin/products/${createdProduct.id}`,
    {
      method: 'DELETE',
      headers: { authorization: `Bearer ${adminSession.token}` },
    },
  );
  assert.equal(deleteProductResponse.status, 200);
  const deletedDetailResponse = await fetch(
    `${baseUrl}/api/products/${createdProduct.id}`,
  );
  assert.equal(deletedDetailResponse.status, 404);
});
