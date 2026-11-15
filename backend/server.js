const path = require('node:path');
require('dotenv').config({ path: path.join(__dirname, '.env') });

const cors = require('cors');
const express = require('express');
const { database } = require('./database');
const adminRoutes = require('./routes/adminRoutes');
const authRoutes = require('./routes/authRoutes');
const couponRoutes = require('./routes/couponRoutes');
const orderRoutes = require('./routes/orderRoutes');
const paymentRoutes = require('./routes/paymentRoutes');
const perfumeRoutes = require('./routes/perfumeRoutes');
const userRoutes = require('./routes/userRoutes');

const app = express();

const corsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);
const allowAnyOrigin =
  corsOrigins.length === 0 || corsOrigins.includes('*');

app.use(
  cors({
    origin: (origin, callback) => {
      callback(
        null,
        !origin || allowAnyOrigin || corsOrigins.includes(origin),
      );
    },
  }),
);
app.use(express.json({ limit: '100kb' }));

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'abaq-api' });
});
app.use('/api/products', perfumeRoutes);
app.use('/api/perfumes', perfumeRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/coupons', couponRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/payment', paymentRoutes);
app.use('/api/users', userRoutes);

app.use((_req, res) => {
  res.status(404).json({ error: 'Route not found.' });
});

app.use((error, _req, res, _next) => {
  if (error.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'Request body must be valid JSON.' });
  }

  console.error(error);
  return res.status(500).json({ error: 'An unexpected server error occurred.' });
});

if (require.main === module) {
  const port = process.env.PORT || 3000;
  database
    .initialize()
    .then(() => {
      app.listen(port, () => {
        console.log(`Abaq API listening on port ${port}`);
      });
    })
    .catch((error) => {
      console.error('Could not initialize the Abaq database.', error);
      process.exitCode = 1;
    });
}

module.exports = app;
