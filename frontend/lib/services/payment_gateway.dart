import 'package:flutter/material.dart';

import '../models/checkout_quote.dart';
import 'payment_gateway_mobile.dart'
    if (dart.library.js_interop) 'payment_gateway_web.dart' as platform;

class PaymentGateway {
  const PaymentGateway._();

  static const publishableKey = String.fromEnvironment(
    'STRIPE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured => publishableKey.isNotEmpty;

  static Future<void> initialize() async {
    if (isConfigured) await platform.initialize(publishableKey);
  }

  static Widget cardEntry(PaymentIntent intent) {
    if (intent.provider != 'stripe') return const SizedBox.shrink();
    return platform.buildCardEntry(intent.clientSecret);
  }

  static Future<void> confirm(PaymentIntent intent) {
    return platform.confirmPayment(intent.clientSecret);
  }
}
