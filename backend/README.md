# Abaq API

Node.js 18+ and npm are required. From this directory:

```shell
npm install
npm start
```

The API listens on port `3000` by default. Cloud platforms can provide `PORT`
to select the listening port. Environment variables are loaded from
`backend/.env` when present; platform-provided environment variables take
precedence.

By default, the API accepts browser requests from any origin. Set
`CORS_ORIGINS` to a comma-separated list of allowed origins (for example,
`https://shop.example.com,https://admin.example.com`) to restrict browser
access. Use `*` to explicitly allow any origin. Keep `.env` files out of source
control and provide production secrets through the deployment platform's secret
manager.

## Persistent data

The API stores users (including scrypt password hashes), products, orders,
account wishlists, coupons, and short-lived payment sessions in
`data/abaq-store.json`. The file is created on first
startup, with the default catalog and demo account (`ali@abaq.com` /
`123456`) plus the admin account (`admin@abaq.com` / `123456`) seeded on first
initialization. Set `ABAQ_DATABASE_PATH` to choose a
different absolute or relative database-file path.

Writes are serialized and persisted through an atomic temporary-file rename.
Back up the JSON file when preserving store data. Bearer sessions remain
in-memory and must be recreated by signing in after a server restart.

## Endpoints

- `GET /api/products?category=oud&search=amber` — list and filter products.
- `GET /api/products/:id` — retrieve one product by ID.
- `GET /api/perfumes?category=oud&search=amber` — list and filter fragrances.
- `GET /api/perfumes/:id` — backward-compatible product lookup.
- `POST /api/orders` — validate and persist an order.
- `POST /api/coupons/validate` — validate a promo code and return a server-priced quote.
- `POST /api/payment/create-intent` — create a Stripe PaymentIntent or development simulation session.
- `POST /api/payment/confirm` — verify payment completion before an order is accepted.
- `GET /api/orders/:invoiceNumber` — retrieve an invoice with its owner's bearer token.
- `POST /api/auth/register` — create an account and session.
- `POST /api/auth/login` — create a session for an existing account.
- `GET /api/auth/me` — retrieve the current profile and validate a bearer session.
- `POST /api/auth/logout` — revoke the current bearer token.
- `POST /api/admin/products` — add a product (administrator only).
- `PUT /api/admin/products/:id` — update product details (administrator only).
- `DELETE /api/admin/products/:id` — remove a product (administrator only).
- `GET /api/admin/orders` — list all orders (administrator only).
- `PUT /api/admin/orders/:id/status` — set an order to `Pending`,
  `Processing`, `Shipped`, or `Delivered` (administrator only).
- `GET /api/users/:userId/orders` — retrieve the authenticated user's orders.
- `GET /api/users/:userId/wishlist` — retrieve the authenticated user's saved product IDs.
- `PUT /api/users/:userId/wishlist` — replace the authenticated user's saved product IDs.
- `GET /health` — service health check.

Demo customer login: `ali@abaq.com` / `123456`.
Demo administrator login: `admin@abaq.com` / `123456`.

Login requests must include `"humanVerified": true`. This checkbox gate is a
basic friction measure, not bot-proof verification; use a CAPTCHA provider
with server-side token verification when stronger automated-abuse protection
is required.

The admin endpoints require an authenticated bearer token whose persisted user
role is `admin`; the client UI does not grant authorization. New accounts are
always created with the `customer` role.

Example COD order body:

```json
{
  "customer": {
    "name": "Sam Example",
    "phone": "+1 555 010 1234",
    "address": "123 Example Street, New York"
  },
  "items": [{ "perfumeId": "oud-royale", "quantity": 1 }],
  "paymentMethod": "COD",
  "totalAmount": 255
}
```

The server calculates shipping ($10, waived when the subtotal exceeds $300)
and verifies `totalAmount` against the catalog. Percentage promo discounts are
calculated against the current catalog subtotal before shipping. Send
`Authorization: Bearer
<token>` to associate an order with the signed-in user; requests without a
token remain guest orders. User history requires a valid token and only the
matching account can read it.

Card orders must include a `paymentIntentId` returned by
`POST /api/payment/create-intent`. The payment session is bound to the
authenticated user (or guest), cart, coupon, and total; it must be confirmed
before the server accepts the order and can be consumed only once.

## Promo codes and payments

The seed catalog includes `ABAQ10` (10% off) and `LUXURY20` (20% off). Coupon
validation accepts `code` and `items` and returns the verified subtotal,
discount, shipping, and total. The order endpoint independently recalculates
these values; client-supplied prices are never trusted.

For real card processing, configure the secret only on the backend:

```shell
STRIPE_SECRET_KEY=sk_live_... npm start
```

Set `ABAQ_PAYMENT_MODE=stripe` to require Stripe explicitly. Build the Flutter
app with its publishable key using
`--dart-define=STRIPE_PUBLISHABLE_KEY=pk_live_...`. Never put the secret key
in the Flutter app or commit either key to source control.

Without a Stripe key, non-production environments use a clearly labeled
simulation that collects no card data and charges no money. Production fails
closed unless Stripe is configured. `ABAQ_ALLOW_SIMULATED_PAYMENTS=true`
explicitly overrides that protection and should only be used in a controlled
test environment.

The product endpoint includes the requested `image`, `rating`,
`isBestseller`, and `isNew` fields while retaining `imageUrl`, `brand`, and
`notes` for the existing Flutter app. Order responses also retain the invoice,
customer, subtotal, discount, shipping, coupon, payment-provider, and currency
fields consumed by Flutter, and include persistent status and tracking-number
fields.
