import 'package:flutter/material.dart';

import '../models/order_invoice.dart';
import '../theme/abaq_theme.dart';

class InvoiceScreen extends StatelessWidget {
  const InvoiceScreen({required this.invoice, this.onContinue, super.key});

  final OrderInvoice invoice;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    final date = invoice.createdAt.toLocal();
    final dateLabel = MaterialLocalizations.of(context).formatMediumDate(date);
    final timeLabel = TimeOfDay.fromDateTime(date).format(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ORDER INVOICE',
          style: TextStyle(fontSize: 11, letterSpacing: 2),
        ),
        centerTitle: true,
        automaticallyImplyLeading: onContinue != null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Icon(Icons.check_circle_outline, size: 46, color: palette.accent),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Thank you for choosing Abaq',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 7),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                invoice.invoiceNumber,
                style: TextStyle(
                  color: palette.accentText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _InvoiceSection(
            title: 'INVOICE DETAILS',
            children: [
              _DetailLine(label: 'Date', value: '$dateLabel · $timeLabel'),
              _DetailLine(
                label: 'Payment',
                value: invoice.paymentMethod == 'COD'
                    ? 'Cash on Delivery'
                    : invoice.paymentProvider == 'simulation'
                    ? 'Card · secure test simulation'
                    : 'Credit / Debit Card',
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InvoiceSection(
            title: 'DELIVER TO',
            children: [
              _DetailLine(label: 'Name', value: invoice.customer.name),
              _DetailLine(label: 'Phone', value: invoice.customer.phone),
              _DetailLine(label: 'Address', value: invoice.customer.address),
            ],
          ),
          const SizedBox(height: 20),
          _InvoiceSection(
            title: 'ITEMS',
            children: [
              for (final item in invoice.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${item.quantity} × ${_money(item.unitPrice, invoice.currency)}',
                              style: TextStyle(
                                color: palette.secondaryText,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(_money(item.lineTotal, invoice.currency)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _InvoiceSection(
            title: 'TOTALS',
            children: [
              _DetailLine(
                label: 'Subtotal',
                value: _money(invoice.subtotal, invoice.currency),
              ),
              if (invoice.discount > 0)
                _DetailLine(
                  label: invoice.couponCode == null
                      ? 'Promo discount'
                      : 'Promo code (${invoice.couponCode})',
                  value: '-${_money(invoice.discount, invoice.currency)}',
                ),
              _DetailLine(
                label: 'Shipping',
                value: invoice.shipping == 0
                    ? 'Complimentary'
                    : _money(invoice.shipping, invoice.currency),
              ),
              const Divider(height: 22),
              _DetailLine(
                label: 'Total',
                value: _money(invoice.totalAmount, invoice.currency),
                emphasized: true,
              ),
            ],
          ),
          const SizedBox(height: 26),
          FilledButton(
            onPressed:
                onContinue ??
                () => Navigator.of(context).popUntil((route) => route.isFirst),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text(
              'CONTINUE SHOPPING',
              style: TextStyle(fontSize: 11, letterSpacing: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _money(double amount, String currency) {
    final symbol = currency == 'USD' ? '\$' : '$currency ';
    return '$symbol${amount.toStringAsFixed(2)}';
  }
}

class _InvoiceSection extends StatelessWidget {
  const _InvoiceSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.border),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    final style = TextStyle(
      fontWeight: emphasized ? FontWeight.w600 : FontWeight.normal,
      fontSize: emphasized ? 16 : 13,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(color: palette.secondaryText, fontSize: 12),
            ),
          ),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}
