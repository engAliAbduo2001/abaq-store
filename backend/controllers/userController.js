const { listOrdersForUser } = require('./orderController');
const { database } = require('../database');

async function getUserOrders(req, res) {
  if (req.params.userId !== req.authUser.id) {
    return res.status(403).json({ error: 'You cannot view another user’s orders.' });
  }

  return res.json({ data: await listOrdersForUser(req.authUser.id) });
}

async function getUserWishlist(req, res) {
  if (req.params.userId !== req.authUser.id) {
    return res.status(403).json({ error: 'You cannot view another user’s wishlist.' });
  }
  return res.json({ data: await database.getWishlist(req.authUser.id) });
}

async function saveUserWishlist(req, res) {
  if (req.params.userId !== req.authUser.id) {
    return res.status(403).json({ error: 'You cannot update another user’s wishlist.' });
  }

  const productIds = req.body?.productIds;
  if (
    !Array.isArray(productIds) ||
    productIds.length > 100 ||
    productIds.some((productId) => typeof productId !== 'string')
  ) {
    return res.status(400).json({
      error: 'productIds must be an array of up to 100 product IDs.',
    });
  }

  const uniqueIds = [...new Set(productIds)];
  const products = await database.getProducts();
  const availableIds = new Set(products.map((product) => product.id));
  const unknownIds = uniqueIds.filter((productId) => !availableIds.has(productId));
  if (unknownIds.length > 0) {
    return res.status(400).json({
      error: 'Wishlist contains unavailable products.',
      details: unknownIds,
    });
  }

  return res.json({
    data: await database.saveWishlist(req.authUser.id, uniqueIds),
  });
}

module.exports = {
  getUserOrders,
  getUserWishlist,
  saveUserWishlist,
};
