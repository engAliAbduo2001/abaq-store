const {
  randomBytes,
  randomUUID,
  scryptSync,
} = require('node:crypto');
const {
  mkdir,
  readFile,
  rename,
  unlink,
  writeFile,
} = require('node:fs/promises');
const path = require('node:path');
const seedCoupons = require('./data/coupons');
const seedPerfumes = require('./data/perfumes');

const databasePath =
  process.env.ABAQ_DATABASE_PATH ||
  path.join(__dirname, 'data', 'abaq-store.json');
const currentVersion = 3;
const orderStatuses = ['Pending', 'Processing', 'Shipped', 'Delivered'];

function createSeedProducts() {
  return seedPerfumes.map((perfume, index) => ({
    ...perfume,
    image: perfume.imageUrl,
    rating: [4.9, 4.8, 4.7, 4.6, 4.8, 4.7][index] || 4.7,
    isBestseller: perfume.badge === 'BESTSELLER',
    isNew: perfume.badge === 'NEW',
  }));
}

function createSeedUser({ name, email, phone, address, password, role }) {
  const salt = randomBytes(16);
  return {
    id: randomUUID(),
    name,
    email,
    phone,
    address,
    role,
    salt: salt.toString('hex'),
    passwordHash: scryptSync(password, salt, 64).toString('hex'),
    createdAt: new Date().toISOString(),
  };
}

function emptyState() {
  return {
    version: currentVersion,
    users: [],
    products: [],
    orders: [],
    wishlists: {},
    coupons: [],
    paymentIntents: [],
  };
}

function normalizeState(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('Abaq database file must contain a JSON object.');
  }
  const version = value.version ?? 1;
  if (!Number.isInteger(version) || version < 1 || version > currentVersion) {
    throw new Error(`Unsupported Abaq database version: ${value.version}.`);
  }

  const state = {
    version: currentVersion,
    users: value.users === undefined ? [] : value.users,
    products: value.products === undefined ? [] : value.products,
    orders: value.orders === undefined ? [] : value.orders,
    wishlists: value.wishlists === undefined ? {} : value.wishlists,
    coupons: value.coupons === undefined ? [] : value.coupons,
    paymentIntents:
      value.paymentIntents === undefined ? [] : value.paymentIntents,
  };
  if (
    !Array.isArray(state.users) ||
    !Array.isArray(state.products) ||
    !Array.isArray(state.orders) ||
    !Array.isArray(state.coupons) ||
    !Array.isArray(state.paymentIntents) ||
    !state.wishlists ||
    typeof state.wishlists !== 'object' ||
    Array.isArray(state.wishlists)
  ) {
    throw new Error('Abaq database file has an invalid data shape.');
  }
  state.users = state.users.map((user) => {
    if (!user || typeof user !== 'object' || Array.isArray(user)) {
      throw new Error('Abaq database contains an invalid user record.');
    }
    return { ...user, role: user.role === 'admin' ? 'admin' : 'customer' };
  });
  state.orders = state.orders.map((order) => {
    if (!order || typeof order !== 'object' || Array.isArray(order)) {
      throw new Error('Abaq database contains an invalid order record.');
    }
    return {
      ...order,
      status: normalizeOrderStatus(order.status),
      trackingNumber:
        typeof order.trackingNumber === 'string' && order.trackingNumber
          ? order.trackingNumber
          : `ABQ-TRK-${randomBytes(4).toString('hex').toUpperCase()}`,
    };
  });
  return state;
}

function normalizeOrderStatus(status) {
  if (orderStatuses.includes(status)) return status;
  const normalized = String(status || '').toLowerCase();
  if (normalized === 'processing') return 'Processing';
  if (normalized === 'shipped') return 'Shipped';
  if (normalized === 'delivered') return 'Delivered';
  return 'Pending';
}

function clone(value) {
  return structuredClone(value);
}

class JsonDatabase {
  constructor({ filePath = databasePath } = {}) {
    this.filePath = filePath;
    this._state = null;
    this._initialization = null;
    this._writeQueue = Promise.resolve();
  }

  async initialize() {
    if (this._state) return;
    if (!this._initialization) {
      this._initialization = this._load();
    }

    try {
      await this._initialization;
    } catch (error) {
      this._initialization = null;
      throw error;
    }
  }

  async _load() {
    await mkdir(path.dirname(this.filePath), {
      recursive: true,
      mode: 0o700,
    });

    let state;
    let shouldPersist = false;
    try {
      const contents = await readFile(this.filePath, 'utf8');
      const parsed = JSON.parse(contents);
      state = normalizeState(parsed);
      shouldPersist = parsed.version !== currentVersion;
      (parsed.users || []).forEach((user, index) => {
        if (user.role !== state.users[index].role) shouldPersist = true;
      });
      (parsed.orders || []).forEach((order, index) => {
        if (
          order.status !== state.orders[index].status ||
          order.trackingNumber !== state.orders[index].trackingNumber
        ) {
          shouldPersist = true;
        }
      });
    } catch (error) {
      if (error.code !== 'ENOENT') {
        if (error instanceof SyntaxError) {
          throw new Error(`Abaq database file is not valid JSON: ${error.message}`);
        }
        throw error;
      }
      state = emptyState();
      shouldPersist = true;
    }

    const isEmpty =
      state.users.length === 0 &&
      state.products.length === 0 &&
      state.orders.length === 0 &&
      Object.keys(state.wishlists).length === 0 &&
      state.coupons.length === 0 &&
      state.paymentIntents.length === 0;
    if (isEmpty) {
      state.products = createSeedProducts();
      shouldPersist = true;
    }
    if (state.coupons.length === 0) {
      state.coupons = seedCoupons.map((coupon) => ({ ...coupon }));
      shouldPersist = true;
    }

    if (
      !state.users.some(
        (user) => user.email.toLowerCase() === 'ali@abaq.com',
      )
    ) {
      state.users.push(
        createSeedUser({
          name: 'Ali Abaq',
          email: 'ali@abaq.com',
          phone: '+971 50 123 4567',
          address: 'Abaq House, Dubai, UAE',
          password: '123456',
          role: 'customer',
        }),
      );
      shouldPersist = true;
    }
    const adminUser = state.users.find(
      (user) => user.email.toLowerCase() === 'admin@abaq.com',
    );
    if (adminUser && adminUser.role !== 'admin') {
      throw new Error(
        'The reserved admin@abaq.com account exists without the admin role.',
      );
    }
    if (!adminUser) {
      state.users.push(
        createSeedUser({
          name: 'Abaq Admin',
          email: 'admin@abaq.com',
          phone: '+971 50 000 0000',
          address: 'Abaq Store Administration',
          password: '123456',
          role: 'admin',
        }),
      );
      shouldPersist = true;
    }

    if (shouldPersist) {
      await this._persist(state);
    }
    this._state = state;
  }

  async _read(readValue) {
    await this.initialize();
    await this._writeQueue;
    return clone(readValue(this._state));
  }

  async _write(update) {
    await this.initialize();
    const operation = this._writeQueue.then(async () => {
      const nextState = clone(this._state);
      const result = update(nextState);
      await this._persist(nextState);
      this._state = nextState;
      return clone(result);
    });

    this._writeQueue = operation.then(
      () => undefined,
      () => undefined,
    );
    return operation;
  }

  async _persist(state) {
    const temporaryPath = `${this.filePath}.${process.pid}.${randomUUID()}.tmp`;
    try {
      await writeFile(temporaryPath, JSON.stringify(state, null, 2), {
        encoding: 'utf8',
        mode: 0o600,
      });
      await rename(temporaryPath, this.filePath);
    } catch (error) {
      try {
        await unlink(temporaryPath);
      } catch (cleanupError) {
        if (cleanupError.code !== 'ENOENT') {
          console.error('Could not remove temporary Abaq database file.', cleanupError);
        }
      }
      throw error;
    }
  }

  getProducts() {
    return this._read((state) => state.products);
  }

  getCouponByCode(code) {
    const normalizedCode = String(code || '').trim().toUpperCase();
    return this._read(
      (state) =>
        state.coupons.find((coupon) => coupon.code === normalizedCode) || null,
    );
  }

  createPaymentIntent(paymentIntent) {
    return this._write((state) => {
      if (
        state.paymentIntents.some(
          (existing) => existing.id === paymentIntent.id,
        )
      ) {
        return null;
      }
      state.paymentIntents.push(paymentIntent);
      return paymentIntent;
    });
  }

  getPaymentIntentById(paymentIntentId) {
    return this._read(
      (state) =>
        state.paymentIntents.find(
          (intent) => intent.id === paymentIntentId,
        ) || null,
    );
  }

  updatePaymentIntentStatus(paymentIntentId, status) {
    return this._write((state) => {
      const intent = state.paymentIntents.find(
        (entry) => entry.id === paymentIntentId,
      );
      if (!intent || intent.consumedAt) return null;
      intent.status = status;
      return intent;
    });
  }

  async getProductById(productId) {
    return this._read(
      (state) => state.products.find((product) => product.id === productId) || null,
    );
  }

  getUserById(userId) {
    return this._read(
      (state) => state.users.find((user) => user.id === userId) || null,
    );
  }

  getUserByEmail(email) {
    const normalizedEmail = email.trim().toLowerCase();
    return this._read(
      (state) =>
        state.users.find((user) => user.email === normalizedEmail) || null,
    );
  }

  createUser(user) {
    return this._write((state) => {
      const exists = state.users.some(
        (existing) => existing.email === user.email,
      );
      if (exists) return null;
      state.users.push(user);
      return user;
    });
  }

  createProduct(product) {
    return this._write((state) => {
      if (state.products.some((existing) => existing.id === product.id)) {
        return null;
      }
      state.products.push(product);
      return product;
    });
  }

  updateProduct(productId, updates) {
    return this._write((state) => {
      const index = state.products.findIndex(
        (product) => product.id === productId,
      );
      if (index < 0) return null;
      state.products[index] = {
        ...state.products[index],
        ...updates,
        id: productId,
      };
      return state.products[index];
    });
  }

  deleteProduct(productId) {
    return this._write((state) => {
      const index = state.products.findIndex(
        (product) => product.id === productId,
      );
      if (index < 0) return null;
      const [product] = state.products.splice(index, 1);
      for (const [userId, productIds] of Object.entries(state.wishlists)) {
        state.wishlists[userId] = productIds.filter((id) => id !== productId);
      }
      return product;
    });
  }

  createOrder(order, paymentIntentId) {
    return this._write((state) => {
      const duplicate = state.orders.some(
        (existing) =>
          existing.id === order.id ||
          existing.invoiceNumber === order.invoiceNumber,
      );
      if (duplicate) return false;
      if (paymentIntentId) {
        const intent = state.paymentIntents.find(
          (entry) => entry.id === paymentIntentId,
        );
        const orderItems = order.items
          .map(({ perfumeId, quantity }) => ({ perfumeId, quantity }))
          .sort((left, right) => left.perfumeId.localeCompare(right.perfumeId));
        const intentItems = intent?.items
          ?.map(({ perfumeId, quantity }) => ({ perfumeId, quantity }))
          .sort((left, right) => left.perfumeId.localeCompare(right.perfumeId));
        if (
          !intent ||
          intent.status !== 'succeeded' ||
          intent.consumedAt ||
          intent.expiresAt <= Date.now() ||
          intent.userId !== order.userId ||
          intent.amountCents !== Math.round(order.totalAmount * 100) ||
          intent.couponCode !== (order.couponCode || null) ||
          JSON.stringify(intentItems) !== JSON.stringify(orderItems)
        ) {
          return false;
        }
        intent.consumedAt = new Date().toISOString();
      }
      state.orders.push(order);
      return true;
    });
  }

  getOrderByInvoiceNumber(invoiceNumber) {
    return this._read(
      (state) =>
        state.orders.find((order) => order.invoiceNumber === invoiceNumber) ||
        null,
    );
  }

  getOrdersForUser(userId) {
    return this._read((state) =>
      state.orders
        .filter((order) => order.userId === userId)
        .sort((left, right) => right.createdAt.localeCompare(left.createdAt)),
    );
  }

  getAllOrders() {
    return this._read((state) =>
      [...state.orders].sort((left, right) =>
        right.createdAt.localeCompare(left.createdAt),
      ),
    );
  }

  updateOrderStatus(orderId, status) {
    return this._write((state) => {
      const order = state.orders.find((entry) => entry.id === orderId);
      if (!order) return null;
      order.status = status;
      return order;
    });
  }

  getWishlist(userId) {
    return this._read((state) => state.wishlists[userId] || []);
  }

  saveWishlist(userId, productIds) {
    return this._write((state) => {
      if (!state.users.some((user) => user.id === userId)) {
        throw new Error('Cannot save a wishlist for an unknown user.');
      }
      const availableIds = new Set(
        state.products.map((product) => product.id),
      );
      if (productIds.some((productId) => !availableIds.has(productId))) {
        throw new Error('Wishlist contains an unknown product.');
      }
      const uniqueIds = [...new Set(productIds)];
      state.wishlists[userId] = uniqueIds;
      return uniqueIds;
    });
  }
}

const database = new JsonDatabase();

module.exports = { JsonDatabase, database };
