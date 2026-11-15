class CheckoutQuote {
  const CheckoutQuote({
    required this.subtotal,
    required this.discount,
    required this.shipping,
    required this.totalAmount,
    this.couponCode,
  });

  final String? couponCode;
  final double subtotal;
  final double discount;
  final double shipping;
  final double totalAmount;

  factory CheckoutQuote.fromJson(Map<String, dynamic> json) {
    final couponCode = json['couponCode'];
    if (couponCode != null && couponCode is! String) {
      throw const FormatException('Coupon code in the quote is invalid.');
    }
    return CheckoutQuote(
      couponCode: couponCode as String?,
      subtotal: _quoteAmount(json, 'subtotal'),
      discount: _quoteAmount(json, 'discount'),
      shipping: _quoteAmount(json, 'shipping'),
      totalAmount: _quoteAmount(json, 'totalAmount'),
    );
  }
}

class PaymentIntent {
  const PaymentIntent({
    required this.id,
    required this.clientSecret,
    required this.provider,
    required this.quote,
  });

  final String id;
  final String clientSecret;
  final String provider;
  final CheckoutQuote quote;

  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    final quote = json['quote'];
    final provider = json['provider'];
    if (quote is! Map ||
        provider is! String ||
        !['stripe', 'simulation'].contains(provider)) {
      throw const FormatException('Payment intent response is invalid.');
    }
    return PaymentIntent(
      id: _quoteString(json, 'paymentIntentId'),
      clientSecret: _quoteString(json, 'clientSecret'),
      provider: provider,
      quote: CheckoutQuote.fromJson(Map<String, dynamic>.from(quote)),
    );
  }
}

double _quoteAmount(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num || !value.isFinite || value < 0) {
    throw FormatException('Quote amount "$key" is invalid.');
  }
  return value.toDouble();
}

String _quoteString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Payment intent field "$key" is invalid.');
  }
  return value;
}
