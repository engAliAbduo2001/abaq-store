import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/checkout_quote.dart';
import '../models/order_invoice.dart';
import '../models/perfume.dart';
import '../services/abaq_api.dart';
import '../services/payment_gateway.dart';
import '../theme/abaq_theme.dart';
import '../widgets/promo_code_box.dart';
import 'invoice_screen.dart';

class CheckoutItem {
  const CheckoutItem({required this.perfume, required this.quantity});

  final Perfume perfume;
  final int quantity;
}

enum _PaymentMethod { cod, card }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    required this.api,
    required this.items,
    required this.onOrderPlaced,
    this.session,
    this.couponCode,
    super.key,
  });

  final AbaqApi api;
  final List<CheckoutItem> items;
  final VoidCallback onOrderPlaced;
  final AuthSession? session;
  final String? couponCode;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _promoController = TextEditingController();

  _PaymentMethod _paymentMethod = _PaymentMethod.cod;
  bool _isSubmitting = false;
  bool _isApplyingPromo = false;
  bool _isPreparingIntent = false;
  String? _submitError;
  String? _promoError;
  CheckoutQuote? _quote;
  PaymentIntent? _paymentIntent;
  int _quoteRequest = 0;
  int _intentRequest = 0;

  double get _catalogSubtotal => widget.items.fold(
    0,
    (total, item) => total + item.perfume.price * item.quantity,
  );

  double get _subtotal => _quote?.subtotal ?? _catalogSubtotal;

  double get _shipping => _quote?.shipping ?? (_catalogSubtotal > 300 ? 0 : 10);

  double get _discount => _quote?.discount ?? 0;

  double get _total => _quote?.totalAmount ?? _subtotal + _shipping;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.session?.user.name ?? '';
    _phoneController.text = widget.session?.user.phone ?? '';
    _addressController.text = widget.session?.user.address ?? '';
    _promoController.text = widget.couponCode ?? '';
    if (widget.couponCode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_applyPromoCode());
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _promoController.dispose();
    super.dispose();
  }

  List<OrderRequestItem> get _orderItems => widget.items
      .map(
        (item) => OrderRequestItem(
          perfumeId: item.perfume.id,
          quantity: item.quantity,
        ),
      )
      .toList();

  void _selectPaymentMethod(_PaymentMethod method) {
    _intentRequest++;
    setState(() {
      _paymentMethod = method;
      _paymentIntent = null;
      _isPreparingIntent = false;
      _submitError = null;
    });
    if (method == _PaymentMethod.card) unawaited(_preparePaymentIntent());
  }

  void _onPromoCodeChanged(String _) {
    _quoteRequest++;
    _intentRequest++;
    setState(() {
      _quote = null;
      _paymentIntent = null;
      _isApplyingPromo = false;
      _isPreparingIntent = false;
      _promoError = null;
      _submitError = null;
    });
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      _quoteRequest++;
      _intentRequest++;
      setState(() {
        _quote = null;
        _paymentIntent = null;
        _isApplyingPromo = false;
        _isPreparingIntent = false;
        _promoError = 'Enter a promo code.';
      });
      return;
    }
    final requestId = ++_quoteRequest;
    _intentRequest++;
    setState(() {
      _isApplyingPromo = true;
      _promoError = null;
      _submitError = null;
      _paymentIntent = null;
      _isPreparingIntent = false;
    });
    try {
      final quote = await widget.api.validateCoupon(
        code: code,
        items: _orderItems,
        token: widget.session?.token,
      );
      if (!mounted || requestId != _quoteRequest) return;
      setState(() {
        _quote = quote;
        _promoController.text = quote.couponCode ?? code;
      });
      if (_paymentMethod == _PaymentMethod.card) {
        await _preparePaymentIntent();
      }
    } on Exception catch (error) {
      if (!mounted || requestId != _quoteRequest) return;
      setState(() {
        _quote = null;
        _promoError = error.toString();
      });
    } finally {
      if (mounted && requestId == _quoteRequest) {
        setState(() => _isApplyingPromo = false);
      }
    }
  }

  void _removePromoCode() {
    _quoteRequest++;
    _intentRequest++;
    setState(() {
      _promoController.clear();
      _quote = null;
      _paymentIntent = null;
      _isApplyingPromo = false;
      _isPreparingIntent = false;
      _promoError = null;
      _submitError = null;
    });
    if (_paymentMethod == _PaymentMethod.card) {
      unawaited(_preparePaymentIntent());
    }
  }

  Future<void> _preparePaymentIntent() async {
    if (_isPreparingIntent || _paymentIntent != null) return;
    if (_promoController.text.trim().isNotEmpty &&
        _quote?.couponCode == null) {
      setState(() {
        _promoError = 'Apply or remove this promo code before paying.';
      });
      return;
    }
    final requestId = ++_intentRequest;
    setState(() {
      _isPreparingIntent = true;
      _submitError = null;
    });
    try {
      final intent = await widget.api.createPaymentIntent(
        items: _orderItems,
        couponCode: _quote?.couponCode,
        token: widget.session?.token,
      );
      if (intent.provider == 'stripe' && !PaymentGateway.isConfigured) {
        throw const AbaqApiException(
          'Stripe is enabled on the server, but this app is missing its '
          'STRIPE_PUBLISHABLE_KEY configuration.',
        );
      }
      if (!mounted || requestId != _intentRequest) return;
      setState(() {
        _paymentIntent = intent;
        _quote = intent.quote;
      });
    } on Exception catch (error) {
      if (!mounted || requestId != _intentRequest) return;
      setState(() => _submitError = error.toString());
    } finally {
      if (mounted && requestId == _intentRequest) {
        setState(() => _isPreparingIntent = false);
      }
    }
  }

  Future<bool> _confirmSimulation() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test payment simulation'),
        content: const Text(
          'This sandbox flow does not collect card details or charge money. '
          'Continue to simulate a successful payment?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            key: const ValueKey('confirm-test-payment'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SIMULATE PAYMENT'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<void> _placeOrder() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    if (_promoController.text.trim().isNotEmpty &&
        _quote?.couponCode == null) {
      setState(() {
        _promoError = 'Apply or remove this promo code before continuing.';
      });
      return;
    }
    if (_paymentMethod == _PaymentMethod.card &&
        (_isApplyingPromo || _isPreparingIntent)) {
      return;
    }
    if (_paymentMethod == _PaymentMethod.card && _paymentIntent == null) {
      await _preparePaymentIntent();
      if (!mounted || _paymentIntent == null) return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final intent = _paymentMethod == _PaymentMethod.card
          ? _paymentIntent
          : null;
      if (intent != null) {
        if (intent.provider == 'simulation') {
          if (!await _confirmSimulation()) return;
          await Future<void>.delayed(const Duration(milliseconds: 350));
        } else {
          await PaymentGateway.confirm(intent);
        }
        await widget.api.confirmPaymentIntent(
          paymentIntentId: intent.id,
          clientSecret:
              intent.provider == 'simulation' ? intent.clientSecret : null,
          token: widget.session?.token,
        );
      }

      final invoice = await widget.api.createOrder(
        customerName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        items: _orderItems,
        paymentMethod: _paymentMethod == _PaymentMethod.cod ? 'COD' : 'Card',
        totalAmount: _total,
        couponCode: _quote?.couponCode,
        paymentIntentId: intent?.id,
        token: widget.session?.token,
      );
      if (!mounted) return;

      widget.onOrderPlaced();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => InvoiceScreen(invoice: invoice),
        ),
        (route) => route.isFirst,
      );
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    final paymentIntent = _paymentIntent;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'CHECKOUT',
          style: TextStyle(fontSize: 11, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const Text(
              'Delivery details',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 7),
            Text(
              'Where should we send your Abaq discovery?',
              style: TextStyle(color: palette.secondaryText),
            ),
            const SizedBox(height: 22),
            _CheckoutField(
              controller: _nameController,
              label: 'Full name',
              textCapitalization: TextCapitalization.words,
              validator: (value) => value == null || value.trim().length < 2
                  ? 'Enter your full name'
                  : null,
            ),
            const SizedBox(height: 14),
            _CheckoutField(
              controller: _phoneController,
              label: 'Phone number',
              keyboardType: TextInputType.phone,
              validator: (value) {
                final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                return digits.length < 7 || digits.length > 15
                    ? 'Enter a valid phone number'
                    : null;
              },
            ),
            const SizedBox(height: 14),
            _CheckoutField(
              controller: _addressController,
              label: 'Delivery address',
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              validator: (value) => value == null || value.trim().length < 5
                  ? 'Enter your delivery address'
                  : null,
            ),
            const SizedBox(height: 26),
            const Text(
              'PAYMENT METHOD',
              style: TextStyle(fontSize: 10, letterSpacing: 1.6),
            ),
            const SizedBox(height: 10),
            _PaymentOption(
              key: const ValueKey('payment-cod'),
              title: 'Cash on Delivery',
              subtitle: 'Pay when your fragrance arrives',
              selected: _paymentMethod == _PaymentMethod.cod,
              onTap: () => _selectPaymentMethod(_PaymentMethod.cod),
            ),
            const SizedBox(height: 9),
            _PaymentOption(
              key: const ValueKey('payment-card'),
              title: 'Credit / Debit Card',
              subtitle: 'Secure checkout through Abaq payments',
              selected: _paymentMethod == _PaymentMethod.card,
              onTap: () => _selectPaymentMethod(_PaymentMethod.card),
            ),
            if (_paymentMethod == _PaymentMethod.card) ...[
              const SizedBox(height: 12),
              if (_isPreparingIntent)
                const Center(child: CircularProgressIndicator())
              else if (paymentIntent != null)
                if (paymentIntent.provider == 'simulation')
                  Container(
                    key: const ValueKey('payment-simulation-notice'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, color: palette.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Sandbox payment session ready. No card details '
                            'are collected and no money will be charged.',
                            style: TextStyle(
                              color: palette.text,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (kIsWeb)
                    PaymentGateway.cardEntry(paymentIntent)
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.verified_user_outlined, color: palette.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your card details are entered securely in the '
                            'Stripe payment sheet.',
                            style: TextStyle(
                              color: palette.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
              else
                Text(
                  _submitError ?? 'Preparing a secure payment session…',
                  style: TextStyle(color: palette.danger, fontSize: 12),
                ),
            ],
            const SizedBox(height: 27),
            const Text(
              'ORDER SUMMARY',
              style: TextStyle(fontSize: 10, letterSpacing: 1.6),
            ),
            const SizedBox(height: 14),
            for (final item in widget.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${item.perfume.name}  ×  ${item.quantity}'),
                    ),
                    Text(
                      '\$${(item.perfume.price * item.quantity).toStringAsFixed(2)}',
                    ),
                  ],
                ),
              ),
            PromoCodeBox(
              key: const ValueKey('checkout-promo-box'),
              controller: _promoController,
              isApplying: _isApplyingPromo,
              error: _promoError,
              appliedCode: _quote?.couponCode,
              discount: _discount,
              onChanged: _onPromoCodeChanged,
              onApply: _applyPromoCode,
              onRemove: _removePromoCode,
            ),
            const SizedBox(height: 14),
            _SummaryLine(label: 'Subtotal', amount: _subtotal),
            if (_discount > 0) ...[
              const SizedBox(height: 9),
              _SummaryLine(
                label: 'Promo discount (${_quote!.couponCode})',
                amount: _discount,
                isDiscount: true,
              ),
            ],
            const SizedBox(height: 9),
            _SummaryLine(
              label: 'Shipping',
              amount: _shipping,
              free: _shipping == 0,
            ),
            const Divider(height: 28),
            _SummaryLine(label: 'Total', amount: _total, bold: true),
            if (_submitError != null) ...[
              const SizedBox(height: 16),
              Text(_submitError!, style: TextStyle(color: palette.danger)),
            ],
            const SizedBox(height: 22),
            FilledButton(
              key: const ValueKey('submit-order'),
              onPressed: _isSubmitting ||
                      _isApplyingPromo ||
                      _isPreparingIntent
                  ? null
                  : _placeOrder,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 17),
              ),
              child: Text(
                _isSubmitting
                    ? 'PROCESSING PAYMENT…'
                    : _isPreparingIntent
                    ? 'PREPARING PAYMENT…'
                    : _paymentMethod == _PaymentMethod.card &&
                          _paymentIntent?.provider == 'simulation'
                    ? 'COMPLETE TEST PAYMENT'
                    : _paymentMethod == _PaymentMethod.card
                    ? 'PAY \$${_total.toStringAsFixed(2)}'
                    : 'PLACE ORDER',
                style: const TextStyle(fontSize: 11, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Material(
      color: selected ? palette.accentSoft : palette.surface,
      elevation: Theme.of(context).brightness == Brightness.light ? 1 : 0,
      shadowColor: palette.shadow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: selected ? palette.accent : palette.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? palette.accent : palette.secondaryText,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutField extends StatelessWidget {
  const _CheckoutField({
    required this.controller,
    required this.label,
    required this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.amount,
    this.free = false,
    this.bold = false,
    this.isDiscount = false,
  });

  final String label;
  final double amount;
  final bool free;
  final bool bold;
  final bool isDiscount;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    final style = TextStyle(
      color: isDiscount
          ? palette.accent
          : bold
          ? palette.text
          : palette.secondaryText,
      fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
      fontSize: bold ? 17 : 14,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(
          free
              ? 'Complimentary'
              : '${isDiscount ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
          style: style,
        ),
      ],
    );
  }
}
