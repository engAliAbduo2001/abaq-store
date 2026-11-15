const { database } = require('../database');

async function getProducts(req, res) {
  const category = String(req.query.category || '').trim().toLowerCase();
  const search = String(req.query.search || '').trim().toLowerCase();
  const products = await database.getProducts();

  const results = products.filter((product) => {
    const matchesCategory =
      !category || product.category.toLowerCase() === category;
    const searchableText = [
      product.name,
      product.brand,
      product.category,
      product.description,
      ...(Array.isArray(product.notes) ? product.notes : []),
    ]
      .join(' ')
      .toLowerCase();
    return matchesCategory && searchableText.includes(search);
  });

  return res.json({ data: results, count: results.length });
}

async function getProductById(req, res) {
  const product = await database.getProductById(req.params.id);
  if (!product) {
    const entityName = req.baseUrl.endsWith('/perfumes') ? 'Perfume' : 'Product';
    return res.status(404).json({ error: `${entityName} not found.` });
  }

  return res.json({ data: product });
}

module.exports = {
  getPerfumeById: getProductById,
  getPerfumes: getProducts,
  getProductById,
  getProducts,
};
