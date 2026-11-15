import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_stripe_web/flutter_stripe_web.dart';

Future<void> initialize(String publishableKey) async {
  Stripe.publishableKey = publishableKey;
  await Stripe.instance.applySettings();
}

Widget buildCardEntry(String clientSecret) {
  return SizedBox(
    height: 245,
    child: PaymentElement(
      clientSecret: clientSecret,
      enablePostalCode: true,
      onCardChanged: (_) {},
    ),
  );
}

Future<void> confirmPayment(String _) async {
  await WebStripe.instance.confirmPaymentElement(
    ConfirmPaymentElementOptions(
      confirmParams: ConfirmPaymentParams(return_url: Uri.base.toString()),
      redirect: PaymentConfirmationRedirect.ifRequired,
    ),
  );
}
