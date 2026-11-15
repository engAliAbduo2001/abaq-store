import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> initialize(String publishableKey) async {
  Stripe.publishableKey = publishableKey;
  await Stripe.instance.applySettings();
}

Widget buildCardEntry(String _) => const SizedBox.shrink();

Future<void> confirmPayment(String clientSecret) async {
  await Stripe.instance.initPaymentSheet(
    paymentSheetParameters: SetupPaymentSheetParameters(
      paymentIntentClientSecret: clientSecret,
      merchantDisplayName: 'Abaq Store',
    ),
  );
  await Stripe.instance.presentPaymentSheet();
}
