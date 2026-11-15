# Abaq Flutter storefront

Run from this directory:

```shell
flutter pub get
flutter run
flutter test
```

The app loads the perfume catalog and submits checkout orders to the Express
API. It falls back to `lib/data/perfume_catalog.dart` when the catalog endpoint
is unavailable and displays a retry notice.

Guests can browse, save wishlist items, and check out without an account.
Sign-in and registration are optional; authenticated orders appear in the
profile's order history, profile details prefill checkout, and account
wishlists sync with the backend. Guest wishlist items are kept in the current
app session and are merged into the account when signing in.

Start the backend from `../backend` with `npm install` and `npm start`. The
Flutter app defaults to `http://10.0.2.2:3000/api/` on Android and
`http://localhost:3000/api/` on web and desktop during development. Set the
compile-time `API_BASE_URL` value to the backend API root (including `/api/`)
to use another environment. Release builds require this value and require an
HTTPS URL. All API requests use this shared configuration.

Checkout supports Cash on Delivery and a simulated card option. Card fields
are validated locally and are never sent to or stored by the backend. Users,
products, orders, invoices, and account wishlists persist in the backend JSON
database; bearer sessions need a new sign-in after the server restarts.

Demo account: `ali@abaq.com` / `123456`.
