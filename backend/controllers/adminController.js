const { randomUUID } = require('node:crypto');
const { database } = require('../database');

const orderStatuses = ['Pending', 'Processing', 'Shipped', 'Delivered'];

function isHttpUrl(value) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' || url.protocol === 'http:';
  } catch {
    return false;
  }
}

function slugify(value) {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

function validateProductInput(body, existing) {
  const errors = [];
  const value = body && typeof body === 'object' && !Array.isArray(body)
    ? body
    : {};

  const name = value.name ?? existing?.name;
  const brand = value.brand ?? existing?.brand ?? 'Abaq Atelier';
  const category = value.category ?? existing?.category;
  const description = value.description ?? existing?.description;
  const rawImage = value.image ?? value.imageUrl ?? existing?.image;
  const price = value.price ?? existing?.price;
  const rating = value.rating ?? existing?.rating ?? 4.5;
  const isBestseller = value.isBestseller ?? existing?.isBestseller ?? false;
  const isNew = value.isNew ?? existing?.isNew ?? false;
  let notes = value.notes ?? existing?.notes ?? [];
  const providedBadge = value.badge ?? existing?.badge;

  if (typeof name !== 'string' || name.trim().length < 2 || name.length > 100) {
    errors.push('name must be between 2 and 100 characters.');
  }
  if (typeof brand !== 'string' || brand.trim().length < 2 || brand.length > 80) {
    errors.push('brand must be between 2 and 80 characters.');
  }
  if (
    typeof category !== 'string' ||
    category.trim().length < 2 ||
    category.length > 40
  ) {
    errors.push('category must be between 2 and 40 characters.');
  }
  if (
    typeof description !== 'string' ||
    description.trim().length < 10 ||
    description.length > 2000
  ) {
    errors.push('description must be between 10 and 2000 characters.');
  }
  if (typeof rawImage !== 'string' || !isHttpUrl(rawImage)) {
    errors.push('image must be an absolute HTTP or HTTPS URL.');
  }
  if (typeof price !== 'number' || !Number.isFinite(price) || price <= 0) {
    errors.push('price must be a positive number.');
  }
  if (
    typeof rating !== 'number' ||
    !Number.isFinite(rating) ||
    rating < 0 ||
    rating > 5
  ) {
    errors.push('rating must be between 0 and 5.');
  }
  if (typeof isBestseller !== 'boolean') {
    errors.push('isBestseller must be a boolean.');
  }
  if (typeof isNew !== 'boolean') {
    errors.push('isNew must be a boolean.');
  }

  if (typeof notes === 'string') {
    notes = notes
      .split(',')
      .map((note) => note.trim())
      .filter(Boolean);
  }
  if (
    !Array.isArray(notes) ||
    notes.length > 12 ||
    notes.some(
      (note) => typeof note !== 'string' || note.trim().length > 60,
    )
  ) {
    errors.push('notes must be an array of up to 12 short strings.');
  }
  if (
    providedBadge != null &&
    (typeof providedBadge !== 'string' || providedBadge.length > 30)
  ) {
    errors.push('badge must be a short string.');
  }

  if (errors.length > 0) return { errors };

  const hasBadgeFlags =
    value.isBestseller !== undefined || value.isNew !== undefined;
  const badge = hasBadgeFlags
    ? isBestseller
      ? 'BESTSELLER'
      : isNew
        ? 'NEW'
        : existing?.badge !== 'BESTSELLER' && existing?.badge !== 'NEW'
          ? (value.badge ?? existing?.badge)
          : undefined
    : (value.badge ?? existing?.badge);
  const id =
    existing?.id ||
    `${slugify(name)}-${randomUUID().slice(0, 8).toLowerCase()}`;
  const image = rawImage.trim();

  return {
    errors,
    product: {
      id,
      name: name.trim(),
      brand: brand.trim(),
      category: category.trim(),
      description: description.trim(),
      notes: notes.map((note) => note.trim()),
      price,
      image,
      imageUrl: image,
      currency: 'USD',
      rating,
      isBestseller,
      isNew,
      ...(badge ? { badge } : {}),
    },
  };
}

async function createProduct(req, res) {
  const { product, errors } = validateProductInput(req.body);
  if (errors.length > 0) {
    return res.status(400).json({ error: 'Invalid product.', details: errors });
  }
  const savedProduct = await database.createProduct(product);
  if (!savedProduct) {
    return res.status(409).json({ error: 'Could not create a unique product ID.' });
  }
  return res.status(201).json({ data: savedProduct });
}

async function updateProduct(req, res) {
  const existing = await database.getProductById(req.params.id);
  if (!existing) {
    return res.status(404).json({ error: 'Product not found.' });
  }

  const { product, errors } = validateProductInput(req.body, existing);
  if (errors.length > 0) {
    return res.status(400).json({ error: 'Invalid product.', details: errors });
  }
  const savedProduct = await database.updateProduct(existing.id, product);
  if (!savedProduct) {
    return res.status(404).json({ error: 'Product not found.' });
  }
  return res.json({ data: savedProduct });
}

async function deleteProduct(req, res) {
  const deletedProduct = await database.deleteProduct(req.params.id);
  if (!deletedProduct) {
    return res.status(404).json({ error: 'Product not found.' });
  }
  return res.json({ data: deletedProduct });
}

async function getOrders(req, res) {
  return res.json({ data: await database.getAllOrders() });
}

async function updateOrderStatus(req, res) {
  const { status } = req.body || {};
  if (!orderStatuses.includes(status)) {
    return res.status(400).json({
      error: `status must be one of: ${orderStatuses.join(', ')}.`,
    });
  }
  const order = await database.updateOrderStatus(req.params.id, status);
  if (!order) {
    return res.status(404).json({ error: 'Order not found.' });
  }
  return res.json({ data: order });
}

module.exports = {
  createProduct,
  deleteProduct,
  getOrders,
  updateOrderStatus,
  updateProduct,
};
