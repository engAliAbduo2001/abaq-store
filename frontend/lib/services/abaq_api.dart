import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/admin_order.dart';
import '../models/auth_session.dart';
import '../models/checkout_quote.dart';
import '../models/order_invoice.dart';
import '../models/perfume.dart';

class AbaqApiException implements Exception {
  const AbaqApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AbaqApi {
  AbaqApi({http.Client? client, Uri? baseUri})
    : _client = client ?? http.Client(),
      _baseUri = baseUri ?? ApiConfig.baseUri;

  final http.Client _client;
  final Uri _baseUri;
  void Function()? onUnauthorized;

  Future<List<Perfume>> fetchPerfumes() async {
    final response = await _client
        .get(_baseUri.resolve('perfumes'))
        .timeout(const Duration(seconds: 5));
    final data = _readData(response);
    if (data is! List) {
      throw const AbaqApiException(
        'The perfume response has an invalid shape.',
      );
    }

    return data.map((record) {
      if (record is! Map) {
        throw const AbaqApiException(
          'The perfume response contains invalid data.',
        );
      }
      return Perfume.fromJson(Map<String, dynamic>.from(record));
    }).toList();
  }

  Future<AuthSession> login({
    required String email,
    required String password,
    required bool humanVerified,
  }) async {
    final response = await _client
        .post(
          _baseUri.resolve('auth/login'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'humanVerified': humanVerified,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _parseSession(response);
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String phone,
    required String address,
    required String password,
  }) async {
    final response = await _client
        .post(
          _baseUri.resolve('auth/register'),
          headers: const {'content-type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'email': email,
            'phone': phone,
            'address': address,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));
    return _parseSession(response);
  }

  Future<AbaqUser> fetchCurrentUser(String token) async {
    final response = await _client
        .get(
          _baseUri.resolve('auth/me'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    final data = _readData(response);
    if (data is! Map) {
      throw const AbaqApiException(
        'The account response has an invalid shape.',
      );
    }
    return AbaqUser.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> logout(String token) async {
    final response = await _client
        .post(
          _baseUri.resolve('auth/logout'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    _readData(response);
  }

  Future<List<OrderInvoice>> fetchUserOrders({
    required String userId,
    required String token,
  }) async {
    final response = await _client
        .get(
          _baseUri.resolve('users/${Uri.encodeComponent(userId)}/orders'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    final data = _readData(response);
    if (data is! List) {
      throw const AbaqApiException('The order history response is invalid.');
    }
    return data.map((record) {
      if (record is! Map) {
        throw const AbaqApiException(
          'The order history contains invalid data.',
        );
      }
      return OrderInvoice.fromJson(Map<String, dynamic>.from(record));
    }).toList();
  }

  Future<Perfume> createAdminProduct({
    required String token,
    required Map<String, Object?> product,
  }) async {
    final response = await _client
        .post(
          _baseUri.resolve('admin/products'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode(product),
        )
        .timeout(const Duration(seconds: 10));
    return _parsePerfume(_readData(response));
  }

  Future<Perfume> updateAdminProduct({
    required String token,
    required String productId,
    required Map<String, Object?> product,
  }) async {
    final response = await _client
        .put(
          _baseUri.resolve('admin/products/${Uri.encodeComponent(productId)}'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode(product),
        )
        .timeout(const Duration(seconds: 10));
    return _parsePerfume(_readData(response));
  }

  Future<void> deleteAdminProduct({
    required String token,
    required String productId,
  }) async {
    final response = await _client
        .delete(
          _baseUri.resolve('admin/products/${Uri.encodeComponent(productId)}'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    _readData(response);
  }

  Future<List<AdminOrder>> fetchAdminOrders({required String token}) async {
    final response = await _client
        .get(
          _baseUri.resolve('admin/orders'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    final data = _readData(response);
    if (data is! List) {
      throw const AbaqApiException('The admin order response is invalid.');
    }
    return data.map((record) {
      if (record is! Map) {
        throw const AbaqApiException('The admin order record is invalid.');
      }
      return AdminOrder.fromJson(Map<String, dynamic>.from(record));
    }).toList();
  }

  Future<AdminOrder> updateAdminOrderStatus({
    required String token,
    required String orderId,
    required String status,
  }) async {
    final response = await _client
        .put(
          _baseUri.resolve(
            'admin/orders/${Uri.encodeComponent(orderId)}/status',
          ),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode({'status': status}),
        )
        .timeout(const Duration(seconds: 10));
    final data = _readData(response);
    if (data is! Map) {
      throw const AbaqApiException('The updated order response is invalid.');
    }
    return AdminOrder.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<String>> fetchUserWishlist({
    required String userId,
    required String token,
  }) async {
    final response = await _client
        .get(
          _baseUri.resolve('users/${Uri.encodeComponent(userId)}/wishlist'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 10));
    final data = _readData(response);
    if (data is! List || data.any((productId) => productId is! String)) {
      throw const AbaqApiException('The wishlist response is invalid.');
    }
    return data.cast<String>();
  }

  Future<void> saveUserWishlist({
    required String userId,
    required String token,
    required List<String> productIds,
  }) async {
    final response = await _client
        .put(
          _baseUri.resolve('users/${Uri.encodeComponent(userId)}/wishlist'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json',
          },
          body: jsonEncode({'productIds': productIds}),
        )
        .timeout(const Duration(seconds: 10));
    _readData(response);
  }

  Future<OrderInvoice> createOrder({
    required String customerName,
    required String phone,
    required String address,
    required List<OrderRequestItem> items,
    required String paymentMethod,
    required double totalAmount,
    String? couponCode,
    String? paymentIntentId,
    String? token,
  }) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (token != null) headers['authorization'] = 'Bearer $token';
    final response = await _client
        .post(
          _baseUri.resolve('orders'),
          headers: headers,
          body: jsonEncode({
            'customer': {
              'name': customerName,
              'phone': phone,
              'address': address,
            },
            'items': items.map((item) => item.toJson()).toList(),
            'paymentMethod': paymentMethod,
            'totalAmount': totalAmount,
            'couponCode': couponCode,
            'paymentIntentId': paymentIntentId,
          }),
        )
        .timeout(const Duration(seconds: 10));
    final data = _readData(response);
    if (data is! Map) {
      throw const AbaqApiException('The order response has an invalid shape.');
    }

    return OrderInvoice.fromJson(Map<String, dynamic>.from(data));
  }

  Future<CheckoutQuote> validateCoupon({
    required String code,
    required List<OrderRequestItem> items,
    String? token,
  }) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (token != null) headers['authorization'] = 'Bearer $token';
    final response = await _client
        .post(
          _baseUri.resolve('coupons/validate'),
          headers: headers,
          body: jsonEncode({
            'code': code,
            'items': items.map((item) => item.toJson()).toList(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    final data = _readData(response);
    if (data is! Map) {
      throw const AbaqApiException('The coupon response is invalid.');
    }
    return CheckoutQuote.fromJson(Map<String, dynamic>.from(data));
  }

  Future<PaymentIntent> createPaymentIntent({
    required List<OrderRequestItem> items,
    String? couponCode,
    String? token,
  }) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (token != null) headers['authorization'] = 'Bearer $token';
    final response = await _client
        .post(
          _baseUri.resolve('payment/create-intent'),
          headers: headers,
          body: jsonEncode({
            'items': items.map((item) => item.toJson()).toList(),
            'couponCode': couponCode,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final data = _readData(response);
    if (data is! Map) {
      throw const AbaqApiException('The payment intent response is invalid.');
    }
    return PaymentIntent.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> confirmPaymentIntent({
    required String paymentIntentId,
    String? clientSecret,
    String? token,
  }) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (token != null) headers['authorization'] = 'Bearer $token';
    final body = <String, Object>{'paymentIntentId': paymentIntentId};
    if (clientSecret != null) body['clientSecret'] = clientSecret;
    final response = await _client
        .post(
          _baseUri.resolve('payment/confirm'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    _readData(response);
  }

  AuthSession _parseSession(http.Response response) {
    final data = _readData(response);
    if (data is! Map) {
      throw const AbaqApiException(
        'The account response has an invalid shape.',
      );
    }
    return AuthSession.fromJson(Map<String, dynamic>.from(data));
  }

  Perfume _parsePerfume(dynamic data) {
    if (data is! Map) {
      throw const AbaqApiException(
        'The product response has an invalid shape.',
      );
    }
    return Perfume.fromJson(Map<String, dynamic>.from(data));
  }

  dynamic _readData(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw const AbaqApiException('The server returned invalid JSON.');
    }
    if (decoded is! Map) {
      throw const AbaqApiException('The server returned an invalid response.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded['error'];
      if (response.statusCode == 401) onUnauthorized?.call();
      throw AbaqApiException(
        message is String
            ? message
            : 'The request failed (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return decoded['data'];
  }

  void close() => _client.close();
}
