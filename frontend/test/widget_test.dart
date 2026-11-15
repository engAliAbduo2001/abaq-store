import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/data/perfume_catalog.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/abaq_api.dart';
import 'package:frontend/services/auth_session_store.dart';
import 'package:frontend/theme/abaq_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Midnight Gold is default and theme toggle switches to ivory', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();

    final themeToggle = find.byKey(const ValueKey('theme-toggle'));
    expect(Theme.of(tester.element(themeToggle)).brightness, Brightness.dark);
    expect(
      Theme.of(
        tester.element(themeToggle),
      ).extension<AbaqPalette>()?.background,
      AbaqPalette.midnightGold.background,
    );

    await tester.tap(themeToggle);
    await tester.pumpAndSettle();

    expect(Theme.of(tester.element(themeToggle)).brightness, Brightness.light);
    expect(
      Theme.of(
        tester.element(themeToggle),
      ).extension<AbaqPalette>()?.background,
      AbaqPalette.noirIvory.background,
    );
    expect(find.byTooltip('Switch to dark mode'), findsOneWidget);
  });

  testWidgets('theme toggle and catalog fit a phone-sized viewport', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('theme-toggle'))),
      ).brightness,
      Brightness.light,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('offline catalog falls back and cart opens', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(AbaqApp(api: _mockApi(offline: true)));
    await tester.pumpAndSettle();

    expect(find.text('A B A Q'), findsOneWidget);
    expect(
      find.text(
        'Showing the saved collection. The live catalog is unavailable.',
      ),
      findsOneWidget,
    );
    expect(find.text('Explore by mood'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-cart')));
    await tester.pumpAndSettle();

    expect(find.text('YOUR BAG'), findsOneWidget);
    expect(find.text('Your bag is empty'), findsOneWidget);
  });

  testWidgets('wishlist supports remove and move to bag actions', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-wishlist')));
    await tester.pumpAndSettle();
    expect(find.text('Your wishlist awaits'), findsOneWidget);
    await tester.tap(find.text('EXPLORE FRAGRANCES'));
    await tester.pumpAndSettle();

    final oudFavorite = find.byKey(const ValueKey('favorite-oud-royale'));
    await tester.ensureVisible(oudFavorite);
    await tester.tap(oudFavorite);
    await tester.pumpAndSettle();

    final roseFavorite = find.byKey(const ValueKey('favorite-desert-rose'));
    await tester.ensureVisible(roseFavorite);
    await tester.tap(roseFavorite);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('open-wishlist')));
    await tester.pumpAndSettle();
    expect(find.text('2 SAVED'), findsOneWidget);
    expect(find.text('Oud Royale'), findsOneWidget);
    expect(find.text('Desert Rose'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove-favorite-desert-rose')));
    await tester.pumpAndSettle();
    expect(find.text('Desert Rose'), findsNothing);
    expect(find.text('1 SAVED'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('move-to-bag-oud-royale')));
    await tester.pump();
    expect(
      tester.widget<SnackBar>(find.byType(SnackBar)).duration,
      const Duration(milliseconds: 1200),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your wishlist awaits'), findsOneWidget);

    await tester.tap(find.text('VIEW BAG'));
    await tester.pumpAndSettle();
    expect(find.text('Oud Royale'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('product details can add and remove a favorite', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    final product = find.byKey(const ValueKey('product-oud-royale'));
    await tester.ensureVisible(product);
    await tester.tap(product);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('detail-favorite')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from wishlist'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-wishlist')));
    await tester.pumpAndSettle();
    expect(find.text('Oud Royale'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('remove-favorite-oud-royale')));
    await tester.pumpAndSettle();
    expect(find.text('Your wishlist awaits'), findsOneWidget);
  });

  testWidgets('demo account opens profile, order history, and logout', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fill-demo-account')));
    await tester.pumpAndSettle();
    final submitButton = find.byKey(const ValueKey('auth-submit'));
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNull);
    await _verifyHuman(tester);
    expect(tester.widget<FilledButton>(submitButton).onPressed, isNotNull);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    expect(find.text('Ali Abaq'), findsOneWidget);
    expect(find.text('ali@abaq.com'), findsOneWidget);
    expect(find.text('MY ORDERS'), findsOneWidget);
    expect(find.text('ABQ-2026-AB12'), findsOneWidget);

    await tester.tap(find.text('ABQ-2026-AB12'));
    await tester.pumpAndSettle();
    expect(find.text('ORDER INVOICE'), findsOneWidget);
    expect(find.text('Oud Royale'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('logout')));
    await tester.tap(find.byKey(const ValueKey('logout')));
    await tester.pumpAndSettle();
    expect(find.text('The collection'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back.'), findsOneWidget);
  });

  testWidgets('admin profile opens dashboard and updates an order status', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'admin@abaq.com');
    await tester.enterText(find.byType(TextFormField).at(1), '123456');
    await _verifyHuman(tester);
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect((await AuthSessionStore().load())?.user.role, 'admin');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    expect(find.text('Abaq Admin'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-admin-dashboard')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('open-admin-dashboard')));
    await tester.pumpAndSettle();
    expect(find.text('ABAQ ADMIN'), findsOneWidget);
    expect(find.text('PRODUCTS'), findsOneWidget);

    await tester.tap(find.text('ADD PERFUME'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('admin-product-name')),
      'Velvet Test',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-product-brand')),
      'Abaq Atelier',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-product-category')),
      'Oriental',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-product-price')),
      '180',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-product-image')),
      'https://example.com/velvet-test.jpg',
    );
    await tester.enterText(
      find.byKey(const ValueKey('admin-product-description')),
      'A refined blend of amber, rose, and soft woods.',
    );
    await tester.tap(find.text('ADD').last);
    await tester.pumpAndSettle();
    expect(find.text('Velvet Test'), findsOneWidget);

    await tester.tap(find.text('ORDERS'));
    await tester.pumpAndSettle();
    expect(find.text('ABQ-2026-AB12'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);

    await tester.tap(find.text('Pending').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shipped').last);
    await tester.pumpAndSettle();
    expect(find.text('SHIPPED'), findsOneWidget);
  });

  testWidgets('saved account restores after app restart and fills checkout', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fill-demo-account')));
    await tester.pumpAndSettle();
    await _verifyHuman(tester);
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    expect(find.text('Ali Abaq'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final perfume = find.byKey(const ValueKey('product-oud-royale'));
    await tester.ensureVisible(perfume);
    await tester.tap(perfume);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-bag')));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-cart')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE TO CHECKOUT'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'Ali Abaq',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '+971 50 123 4567',
    );
  });

  testWidgets('rejected saved token is cleared and redirects to sign in', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fill-demo-account')));
    await tester.pumpAndSettle();
    await _verifyHuman(tester);
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(AbaqApp(api: _mockApi(rejectStoredSession: true)));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back.'), findsOneWidget);
    expect(await AuthSessionStore().load(), isNull);
  });

  testWidgets('signed-in wishlist syncs with the account', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    final persistedWishlist = <String, List<String>>{};
    await tester.pumpWidget(
      AbaqApp(api: _mockApi(wishlistStore: persistedWishlist)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fill-demo-account')));
    await tester.pumpAndSettle();
    await _verifyHuman(tester);
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();

    final favorite = find.byKey(const ValueKey('favorite-oud-royale'));
    await tester.ensureVisible(favorite);
    await tester.tap(favorite);
    await tester.pumpAndSettle();
    expect(persistedWishlist['demo-user-id'], contains('oud-royale'));

    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logout')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('fill-demo-account')));
    await tester.pumpAndSettle();
    await _verifyHuman(tester);
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove Oud Royale from wishlist'), findsOneWidget);
  });

  testWidgets('registration switches modes and checkout uses profile details', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    await tester.pumpWidget(AbaqApp(api: _mockApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('switch-auth-mode')));
    await tester.pumpAndSettle();

    expect(find.text('A place of your own.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Nora Example');
    await tester.enterText(find.byType(TextFormField).at(1), '+1 555 010 1234');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      '456 Example Avenue, New York',
    );
    await tester.enterText(
      find.byType(TextFormField).at(3),
      'nora@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(4), 'secret123');
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('product-oud-royale')),
    );
    await tester.tap(find.byKey(const ValueKey('product-oud-royale')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-bag')));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-cart')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CONTINUE TO CHECKOUT'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller!
          .text,
      'Nora Example',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(1))
          .controller!
          .text,
      '+1 555 010 1234',
    );
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(2))
          .controller!
          .text,
      '456 Example Avenue, New York',
    );
  });

  testWidgets('customer can apply a coupon and complete a test card payment', (
    WidgetTester tester,
  ) async {
    _setLargeViewport(tester);
    final orderBodies = <Map<String, dynamic>>[];
    await tester.pumpWidget(AbaqApp(api: _mockApi(orderBodies: orderBodies)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-toggle')));
    await tester.pumpAndSettle();

    final product = find.byKey(const ValueKey('product-oud-royale'));
    await tester.ensureVisible(product);
    await tester.tap(product);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-to-bag')));
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-cart')));
    await tester.pumpAndSettle();
    expect(find.text('Oud Royale'), findsOneWidget);
    expect(find.text('\$255.00'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('promo-code-input')),
      'NOT_A_CODE',
    );
    await tester.tap(find.byKey(const ValueKey('apply-promo-code')));
    await tester.pumpAndSettle();
    expect(
      find.text('This promo code is invalid or inactive.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('promo-code-input')),
      'ABAQ10',
    );
    await tester.tap(find.byKey(const ValueKey('apply-promo-code')));
    await tester.pumpAndSettle();
    expect(find.text('ABAQ10 applied · You save \$24.50'), findsOneWidget);
    expect(find.text('-\$24.50'), findsOneWidget);
    expect(find.text('\$230.50'), findsOneWidget);

    await tester.tap(find.text('CONTINUE TO CHECKOUT'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('payment-card')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('payment-simulation-notice')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('submit-order')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your full name'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Sam Example');
    await tester.enterText(find.byType(TextFormField).at(1), '+1 555 010 1234');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      '123 Example Street, New York',
    );
    await tester.tap(find.byKey(const ValueKey('submit-order')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-test-payment')));
    await tester.pumpAndSettle();

    expect(find.text('ABQ-2026-AB12'), findsOneWidget);
    expect(find.text('Sam Example'), findsOneWidget);
    expect(find.text('Card · secure test simulation'), findsOneWidget);
    expect(find.text('\$245.00'), findsNWidgets(2));
    expect(find.text('-\$24.50'), findsOneWidget);
    expect(find.text('\$10.00'), findsOneWidget);
    expect(find.text('\$230.50'), findsOneWidget);
    expect(orderBodies, hasLength(1));
    expect(orderBodies.single['paymentMethod'], 'Card');
    expect(orderBodies.single['couponCode'], 'ABAQ10');
    expect(orderBodies.single['totalAmount'], 230.5);
    expect(orderBodies.single.containsKey('cardNumber'), isFalse);
    expect(orderBodies.single.containsKey('cvv'), isFalse);

    await tester.tap(find.text('CONTINUE SHOPPING'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-cart')));
    await tester.pumpAndSettle();
    expect(find.text('Your bag is empty'), findsOneWidget);
  });
}

void _setLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _verifyHuman(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('human-verification')));
  await tester.pumpAndSettle();
}

AbaqApi _mockApi({
  bool offline = false,
  bool rejectStoredSession = false,
  List<Map<String, dynamic>>? orderBodies,
  List<String?>? orderAuthorization,
  Map<String, List<String>>? wishlistStore,
}) {
  final wishlists = wishlistStore ?? <String, List<String>>{};
  var adminOrderStatus = 'Pending';
  final client = MockClient((request) async {
    if (request.method == 'POST' && request.url.path.endsWith('/auth/login')) {
      final credentials = jsonDecode(request.body) as Map<String, dynamic>;
      if (credentials['humanVerified'] != true) {
        return http.Response(
          '{"error":"Human verification is required."}',
          400,
        );
      }
      if (credentials['email'] == 'admin@abaq.com' &&
          credentials['password'] == '123456') {
        return jsonResponse({
          'data': {'token': 'admin-token', 'user': _adminUser},
        }, 200);
      }
      if (credentials['email'] == 'ali@abaq.com' &&
          credentials['password'] == '123456') {
        return jsonResponse({
          'data': {'token': 'demo-token', 'user': _demoUser},
        }, 200);
      }
      return http.Response('{"error":"Email or password is incorrect."}', 401);
    }

    if (request.method == 'POST' &&
        request.url.path.endsWith('/auth/register')) {
      final registration = jsonDecode(request.body) as Map<String, dynamic>;
      return jsonResponse({
        'data': {
          'token': 'registered-token',
          'user': {
            'id': 'registered-user-id',
            'name': registration['name'],
            'email': registration['email'],
            'phone': registration['phone'],
            'address': registration['address'],
          },
        },
      }, 201);
    }

    if (request.method == 'POST' && request.url.path.endsWith('/auth/logout')) {
      return jsonResponse({
        'data': {'signedOut': true},
      }, 200);
    }

    if (request.method == 'GET' && request.url.path.endsWith('/auth/me')) {
      if (rejectStoredSession) {
        return http.Response('{"error":"Session is invalid or expired."}', 401);
      }
      final authorization = request.headers['authorization'];
      final user = switch (authorization) {
        'Bearer demo-token' => _demoUser,
        'Bearer admin-token' => _adminUser,
        'Bearer registered-token' => {
          'id': 'registered-user-id',
          'name': 'Nora Example',
          'email': 'nora@example.com',
          'phone': '+1 555 010 1234',
          'address': '456 Example Avenue, New York',
        },
        _ => null,
      };
      if (user == null) {
        return http.Response('{"error":"Session is invalid or expired."}', 401);
      }
      return jsonResponse({'data': user}, 200);
    }

    if (request.method == 'GET' &&
        request.url.path.contains('/users/') &&
        request.url.path.endsWith('/orders')) {
      final userId = request.url.path.split('/').reversed.skip(1).first;
      final authorization = request.headers['authorization'];
      if (userId == 'demo-user-id' && authorization == 'Bearer demo-token') {
        return jsonResponse({
          'data': [_sampleInvoice()],
        }, 200);
      }
      if (userId == 'registered-user-id' &&
          authorization == 'Bearer registered-token') {
        return jsonResponse({'data': []}, 200);
      }
      if (userId == 'admin-user-id' && authorization == 'Bearer admin-token') {
        return jsonResponse({'data': []}, 200);
      }
      return http.Response('{"error":"Unauthorized"}', 401);
    }

    if (request.method == 'POST' &&
        request.url.path.endsWith('/admin/products')) {
      if (request.headers['authorization'] != 'Bearer admin-token') {
        return http.Response('{"error":"Forbidden"}', 403);
      }
      final product = jsonDecode(request.body) as Map<String, dynamic>;
      return jsonResponse({
        'data': {
          ...product,
          'id': 'admin-product-id',
          'image': product['imageUrl'],
          'currency': 'USD',
        },
      }, 201);
    }

    if (request.url.path.endsWith('/admin/orders') && request.method == 'GET') {
      if (request.headers['authorization'] != 'Bearer admin-token') {
        return http.Response('{"error":"Forbidden"}', 403);
      }
      return jsonResponse({
        'data': [
          {
            'id': 'admin-order-id',
            'status': adminOrderStatus,
            ..._sampleInvoice(),
          },
        ],
      }, 200);
    }

    if (request.method == 'PUT' &&
        request.url.path.endsWith('/admin/orders/admin-order-id/status')) {
      if (request.headers['authorization'] != 'Bearer admin-token') {
        return http.Response('{"error":"Forbidden"}', 403);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      adminOrderStatus = body['status'] as String;
      return jsonResponse({
        'data': {
          'id': 'admin-order-id',
          'status': adminOrderStatus,
          ..._sampleInvoice(),
        },
      }, 200);
    }

    if (request.url.path.contains('/users/') &&
        request.url.path.endsWith('/wishlist')) {
      final userId = request.url.path.split('/').reversed.skip(1).first;
      final authorization = request.headers['authorization'];
      final isAuthorized =
          (userId == 'demo-user-id' && authorization == 'Bearer demo-token') ||
          (userId == 'admin-user-id' &&
              authorization == 'Bearer admin-token') ||
          (userId == 'registered-user-id' &&
              authorization == 'Bearer registered-token');
      if (!isAuthorized) {
        return http.Response('{"error":"Unauthorized"}', 401);
      }
      if (request.method == 'GET') {
        return jsonResponse({'data': wishlists[userId] ?? []}, 200);
      }
      if (request.method == 'PUT') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final productIds = (body['productIds'] as List).cast<String>();
        wishlists[userId] = productIds;
        return jsonResponse({'data': productIds}, 200);
      }
    }

    if (request.method == 'GET' && request.url.path.endsWith('/perfumes')) {
      if (offline) {
        throw http.ClientException('API is offline', request.url);
      }
      return jsonResponse({
        'count': perfumeCatalog.length,
        'data': perfumeCatalog
            .map(
              (perfume) => {
                'id': perfume.id,
                'name': perfume.name,
                'brand': perfume.brand,
                'category': perfume.category,
                'description': perfume.description,
                'notes': perfume.notes,
                'price': perfume.price,
                'imageUrl': perfume.imageUrl,
                'badge': perfume.badge,
              },
            )
            .toList(),
      }, 200);
    }

    if (request.method == 'POST' &&
        request.url.path.endsWith('/coupons/validate')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final code = body['code'] as String?;
      if (code != 'ABAQ10' && code != 'LUXURY20') {
        return http.Response(
          '{"error":"This promo code is invalid or inactive."}',
          400,
        );
      }
      return jsonResponse({'data': _quoteFor(body)}, 200);
    }

    if (request.method == 'POST' &&
        request.url.path.endsWith('/payment/create-intent')) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      return jsonResponse({
        'data': {
          'paymentIntentId': 'test-payment-intent',
          'clientSecret': 'sim_secret_test',
          'provider': 'simulation',
          'quote': _quoteFor(body),
        },
      }, 201);
    }

    if (request.method == 'POST' &&
        request.url.path.endsWith('/payment/confirm')) {
      return jsonResponse({
        'data': {'status': 'succeeded'},
      }, 200);
    }

    if (request.method == 'POST' && request.url.path.endsWith('/orders')) {
      final order = jsonDecode(request.body) as Map<String, dynamic>;
      orderBodies?.add(order);
      orderAuthorization?.add(request.headers['authorization']);
      final items = (order['items'] as List).map((value) {
        final item = Map<String, dynamic>.from(value as Map);
        final perfume = perfumeCatalog.singleWhere(
          (entry) => entry.id == item['perfumeId'],
        );
        final quantity = item['quantity'] as int;
        return {
          'perfumeId': perfume.id,
          'name': perfume.name,
          'quantity': quantity,
          'unitPrice': perfume.price,
          'lineTotal': perfume.price * quantity,
        };
      }).toList();
      final quote = _quoteFor(order);
      return jsonResponse({
        'data': {
          ..._sampleInvoice(
            customer: Map<String, dynamic>.from(order['customer'] as Map),
            items: items,
            paymentMethod: order['paymentMethod'] as String,
            paymentProvider: order['paymentMethod'] == 'Card'
                ? 'simulation'
                : null,
            couponCode: quote['couponCode'] as String?,
            subtotal: quote['subtotal'] as double,
            discount: quote['discount'] as double,
            shipping: quote['shipping'] as double,
            totalAmount: quote['totalAmount'] as double,
          ),
        },
      }, 201);
    }

    return http.Response('{"error":"Not found"}', 404);
  });
  return AbaqApi(
    client: client,
    baseUri: Uri.parse('http://localhost:3000/api/'),
  );
}

Map<String, dynamic> _quoteFor(Map<String, dynamic> body) {
  final code = (body['code'] ?? body['couponCode']) as String?;
  final items = body['items'] as List;
  final subtotal = items.fold<double>(0, (total, value) {
    final item = Map<String, dynamic>.from(value as Map);
    final perfume = perfumeCatalog.singleWhere(
      (entry) => entry.id == item['perfumeId'],
    );
    return total + perfume.price * (item['quantity'] as int);
  });
  final discountRate = switch (code) {
    'ABAQ10' => 0.1,
    'LUXURY20' => 0.2,
    _ => 0.0,
  };
  final discount = (subtotal * discountRate * 100).round() / 100;
  final shipping = subtotal > 300 ? 0.0 : 10.0;
  return {
    'couponCode': code,
    'subtotal': subtotal,
    'discount': discount,
    'shipping': shipping,
    'totalAmount': subtotal - discount + shipping,
  };
}

Map<String, dynamic> get _demoUser => {
  'id': 'demo-user-id',
  'name': 'Ali Abaq',
  'email': 'ali@abaq.com',
  'phone': '+971 50 123 4567',
  'address': 'Abaq House, Dubai, UAE',
  'role': 'customer',
};

Map<String, dynamic> get _adminUser => {
  'id': 'admin-user-id',
  'name': 'Abaq Admin',
  'email': 'admin@abaq.com',
  'phone': '+971 50 000 0000',
  'address': 'Abaq Store Administration',
  'role': 'admin',
};

Map<String, dynamic> _sampleInvoice({
  Map<String, dynamic>? customer,
  List<Map<String, dynamic>>? items,
  String paymentMethod = 'COD',
  String? paymentProvider,
  String? couponCode,
  double subtotal = 245,
  double discount = 0,
  double shipping = 10,
  double totalAmount = 255,
}) {
  return {
    'invoiceNumber': 'ABQ-2026-AB12',
    'createdAt': DateTime.utc(2026, 11, 14, 11).toIso8601String(),
    'customer':
        customer ??
        {
          'name': 'Ali Abaq',
          'phone': '+971 50 123 4567',
          'address': 'Abaq House, Dubai, UAE',
        },
    'items':
        items ??
        [
          {
            'perfumeId': 'oud-royale',
            'name': 'Oud Royale',
            'quantity': 1,
            'unitPrice': 245,
            'lineTotal': 245,
          },
        ],
    'paymentMethod': paymentMethod,
    'paymentProvider': paymentProvider,
    'couponCode': couponCode,
    'subtotal': subtotal,
    'discount': discount,
    'shipping': shipping,
    'totalAmount': totalAmount,
    'currency': 'USD',
  };
}

http.Response jsonResponse(Object body, int statusCode) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
