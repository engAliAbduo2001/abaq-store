import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/order_invoice.dart';
import '../services/abaq_api.dart';
import '../theme/abaq_theme.dart';
import 'admin_dashboard_screen.dart';
import 'invoice_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.api,
    required this.session,
    required this.onLogout,
    super.key,
  });

  final AbaqApi api;
  final AuthSession session;
  final Future<bool> Function() onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoadingOrders = true;
  bool _isLoggingOut = false;
  String? _ordersError;
  List<OrderInvoice> _orders = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoadingOrders = true;
      _ordersError = null;
    });
    try {
      final orders = await widget.api.fetchUserOrders(
        userId: widget.session.user.id,
        token: widget.session.token,
      );
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoadingOrders = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _ordersError = error.toString();
        _isLoadingOrders = false;
      });
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    final messenger = ScaffoldMessenger.of(context);
    late final bool sessionRevoked;
    try {
      sessionRevoked = await widget.onLogout();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isLoggingOut = false);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not sign out locally: $error'),
          duration: const Duration(milliseconds: 1200),
        ),
      );
      return;
    }
    if (!mounted) return;

    Navigator.of(context).popUntil((route) => route.isFirst);
    if (!sessionRevoked) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Signed out on this device. The server session could not be revoked.',
          ),
          duration: Duration(milliseconds: 1200),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    final user = widget.session.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MY ACCOUNT',
          style: TextStyle(fontSize: 11, letterSpacing: 2),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 27,
                  backgroundColor: palette.accentSoft,
                  child: Text(
                    user.name.trim().isEmpty
                        ? 'A'
                        : user.name.trim().characters.first.toUpperCase(),
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: TextStyle(
                          color: palette.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const _SectionHeading(title: 'PERSONAL DETAILS'),
          const SizedBox(height: 10),
          _ProfileDetails(user: user),
          const SizedBox(height: 26),
          if (user.isAdmin) ...[
            FilledButton.icon(
              key: const ValueKey('open-admin-dashboard'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AdminDashboardScreen(
                    api: widget.api,
                    token: widget.session.token,
                  ),
                ),
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text(
                'ADMIN DASHBOARD',
                style: TextStyle(fontSize: 11, letterSpacing: 1.1),
              ),
            ),
            const SizedBox(height: 24),
          ],
          Row(
            children: [
              const Expanded(child: _SectionHeading(title: 'MY ORDERS')),
              IconButton(
                onPressed: _isLoadingOrders ? null : _loadOrders,
                tooltip: 'Refresh orders',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (_isLoadingOrders)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_ordersError != null)
            _OrdersMessage(
              message: 'We could not load your orders. $_ordersError',
              actionLabel: 'RETRY',
              onPressed: _loadOrders,
            )
          else if (_orders.isEmpty)
            const _OrdersMessage(
              message: 'Your order history will appear here after checkout.',
            )
          else
            for (final order in _orders) ...[
              const SizedBox(height: 9),
              _OrderHistoryTile(
                order: order,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => InvoiceScreen(
                      invoice: order,
                      onContinue: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ),
            ],
          const SizedBox(height: 28),
          OutlinedButton.icon(
            key: const ValueKey('logout'),
            onPressed: _isLoggingOut ? null : _logout,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.danger,
              side: BorderSide(color: palette.danger.withValues(alpha: 0.6)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            icon: _isLoggingOut
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout, size: 18),
            label: const Text(
              'SIGN OUT',
              style: TextStyle(fontSize: 11, letterSpacing: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.user});

  final AbaqUser user;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(11),
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
        children: [
          _DetailRow(icon: Icons.phone_outlined, value: user.phone),
          const Divider(height: 1),
          _DetailRow(icon: Icons.location_on_outlined, value: user.address),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: palette.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 10, letterSpacing: 1.6),
    );
  }
}

class _OrdersMessage extends StatelessWidget {
  const _OrdersMessage({
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

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
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onPressed, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _OrderHistoryTile extends StatelessWidget {
  const _OrderHistoryTile({required this.order, required this.onTap});

  final OrderInvoice order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(order.createdAt.toLocal());
    return Material(
      color: palette.surface,
      elevation: Theme.of(context).brightness == Brightness.light ? 1 : 0,
      shadowColor: palette.shadow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(
          order.invoiceNumber,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '$date  ·  ${order.items.length} ${order.items.length == 1 ? 'item' : 'items'}',
          style: TextStyle(color: palette.secondaryText, fontSize: 11),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              'VIEW INVOICE',
              style: TextStyle(
                color: palette.text,
                fontSize: 8,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        leading: Icon(Icons.receipt_long_outlined, color: palette.accent),
      ),
    );
  }
}
