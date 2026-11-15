import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/checkout_quote.dart';
import '../models/order_invoice.dart';
import '../models/perfume.dart';
import '../services/abaq_api.dart';
import '../theme/abaq_theme.dart';
import '../widgets/promo_code_box.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({
    required this.cart,
    required this.catalog,
    required this.api,
    this.session,
    required this.onQuantityChanged,
    required this.onOrderPlaced,
    super.key,
  });

  final Map<String, int> cart;
  final List<Perfume> catalog;
  final AbaqApi api;
  final AuthSession? session;
  final void Function(String perfumeId, int quantity) onQuantityChanged;
  final VoidCallback onOrderPlaced;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final _promoController = TextEditingController();
  CheckoutQuote? _quote;
  String? _promoError;
  bool _isApplyingPromo = false;
  int _quoteRequest = 0;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  List<Perfume> get _items => widget.catalog
      .where((perfume) => widget.cart.containsKey(perfume.id))
      .toList();

  double get _subtotal => _items.fold(
    0,
    (total, perfume) => total + perfume.price * (widget.cart[perfume.id] ?? 0),
  );

  double get _shipping => _subtotal > 300 ? 0 : 10;

  double get _discount => _quote?.discount ?? 0;

  double get _total => _quote?.totalAmount ?? _subtotal + _shipping;

  void _changeQuantity(Perfume perfume, int quantity) {
    final appliedCode =
        _quote?.couponCode ??
        (_isApplyingPromo ? _promoController.text.trim() : null);
    _quoteRequest++;
    widget.onQuantityChanged(perfume.id, quantity);
    setState(() {
      _quote = null;
      _promoError = null;
      _isApplyingPromo = false;
      if (appliedCode != null) _promoController.text = appliedCode;
    });
    if (appliedCode != null && widget.cart.isNotEmpty) {
      unawaited(_applyPromoCode());
    }
  }

  Future<void> _applyPromoCode() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      _quoteRequest++;
      setState(() {
        _quote = null;
        _isApplyingPromo = false;
        _promoError = 'Enter a promo code.';
      });
      return;
    }
    final requestId = ++_quoteRequest;
    setState(() {
      _isApplyingPromo = true;
      _promoError = null;
    });
    try {
      final quote = await widget.api.validateCoupon(
        code: code,
        items: _items
            .map(
              (perfume) => OrderRequestItem(
                perfumeId: perfume.id,
                quantity: widget.cart[perfume.id] ?? 0,
              ),
            )
            .toList(),
        token: widget.session?.token,
      );
      if (!mounted || requestId != _quoteRequest) return;
      setState(() {
        _quote = quote;
        _promoController.text = quote.couponCode ?? code;
      });
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

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'YOUR BAG',
          style: TextStyle(fontSize: 11, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: items.isEmpty
          ? _EmptyCart(onContinue: () => Navigator.of(context).pop())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  '${items.length} ${items.length == 1 ? 'fragrance' : 'fragrances'} selected',
                  style: TextStyle(color: palette.secondaryText),
                ),
                const SizedBox(height: 18),
                for (final perfume in items) ...[
                  _CartLine(
                    perfume: perfume,
                    quantity: widget.cart[perfume.id] ?? 0,
                    onQuantityChanged: (quantity) =>
                        _changeQuantity(perfume, quantity),
                  ),
                  const Divider(height: 24),
                ],
                PromoCodeBox(
                  key: const ValueKey('cart-promo-box'),
                  controller: _promoController,
                  isApplying: _isApplyingPromo,
                  error: _promoError,
                  appliedCode: _quote?.couponCode,
                  discount: _discount,
                  onChanged: (_) {
                    _quoteRequest++;
                    setState(() {
                      _quote = null;
                      _isApplyingPromo = false;
                      _promoError = null;
                    });
                  },
                  onApply: _applyPromoCode,
                  onRemove: () {
                    _quoteRequest++;
                    setState(() {
                      _quote = null;
                      _isApplyingPromo = false;
                      _promoError = null;
                      _promoController.clear();
                    });
                  },
                ),
                const SizedBox(height: 18),
                const SizedBox(height: 12),
                _PriceLine(label: 'Subtotal', amount: _subtotal),
                if (_discount > 0) ...[
                  const SizedBox(height: 10),
                  _PriceLine(
                    label: 'Promo discount',
                    amount: -_discount,
                    isDiscount: true,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Expanded(child: Text('Delivery')),
                    Text(
                      _shipping == 0
                          ? 'Complimentary'
                          : '\$${_shipping.toStringAsFixed(2)}',
                      style: TextStyle(color: palette.secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                const Divider(),
                const SizedBox(height: 13),
                _PriceLine(
                  label: 'Total',
                  amount: _total,
                  isTotal: true,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => CheckoutScreen(
                        api: widget.api,
                        session: widget.session,
                        items: _items
                            .map(
                              (perfume) => CheckoutItem(
                                perfume: perfume,
                                quantity: widget.cart[perfume.id] ?? 0,
                              ),
                            )
                            .toList(),
                        couponCode: _quote?.couponCode,
                        onOrderPlaced: widget.onOrderPlaced,
                      ),
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                  ),
                  child: const Text(
                    'CONTINUE TO CHECKOUT',
                    style: TextStyle(fontSize: 11, letterSpacing: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Complimentary delivery on orders over \$300',
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine({
    required this.perfume,
    required this.quantity,
    required this.onQuantityChanged,
  });

  final Perfume perfume;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Image.network(
            perfume.imageUrl,
            width: 78,
            height: 92,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              width: 78,
              height: 92,
              color: palette.surfaceMuted,
              child: Icon(Icons.spa_outlined, color: palette.accent),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                perfume.brand.toUpperCase(),
                style: TextStyle(
                  color: palette.secondaryText,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                perfume.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 9),
              Text(
                '\$${perfume.price.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
        Row(
          children: [
            _QuantityButton(
              icon: Icons.remove,
              tooltip: 'Remove one',
              onPressed: () => onQuantityChanged(quantity - 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('$quantity'),
            ),
            _QuantityButton(
              icon: Icons.add,
              tooltip: 'Add one',
              onPressed: () => onQuantityChanged(quantity + 1),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: 17,
      icon: Icon(icon),
    );
  }
}

class _PriceLine extends StatelessWidget {
  const _PriceLine({
    required this.label,
    required this.amount,
    this.isTotal = false,
    this.isDiscount = false,
  });

  final String label;
  final double amount;
  final bool isTotal;
  final bool isDiscount;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 17 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          '${isDiscount ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: isDiscount ? palette.accent : palette.text,
            fontSize: isTotal ? 17 : 14,
            fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 42, color: palette.accent),
            const SizedBox(height: 18),
            Text(
              'Your bag is empty',
              style: TextStyle(
                color: palette.text,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find a fragrance that feels like you.',
              style: TextStyle(color: palette.secondaryText),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onContinue,
              child: const Text('EXPLORE THE COLLECTION'),
            ),
          ],
        ),
      ),
    );
  }
}
