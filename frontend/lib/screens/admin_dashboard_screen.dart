import 'package:flutter/material.dart';

import '../models/admin_order.dart';
import '../models/perfume.dart';
import '../services/abaq_api.dart';
import '../theme/abaq_theme.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    required this.api,
    required this.token,
    super.key,
  });

  final AbaqApi api;
  final String token;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const _statuses = ['Pending', 'Processing', 'Shipped', 'Delivered'];

  late final TabController _tabs;
  List<Perfume> _products = [];
  List<AdminOrder> _orders = [];
  final Set<String> _deletingProductIds = {};
  bool _isLoadingProducts = true;
  bool _isLoadingOrders = true;
  bool _isSavingProduct = false;
  String? _productsError;
  String? _ordersError;
  String? _updatingOrderId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
    _loadProducts();
    _loadOrders();
  }

  @override
  void dispose() {
    _tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });
    try {
      final products = await widget.api.fetchPerfumes();
      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoadingProducts = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _productsError = error.toString();
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoadingOrders = true;
      _ordersError = null;
    });
    try {
      final orders = await widget.api.fetchAdminOrders(token: widget.token);
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

  Future<void> _showProductForm([Perfume? product]) async {
    final payload = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _ProductFormDialog(product: product),
    );
    if (payload == null || !mounted) return;

    setState(() => _isSavingProduct = true);
    try {
      final saved = product == null
          ? await widget.api.createAdminProduct(
              token: widget.token,
              product: payload,
            )
          : await widget.api.updateAdminProduct(
              token: widget.token,
              productId: product.id,
              product: payload,
            );
      if (!mounted) return;
      setState(() {
        final index = _products.indexWhere((item) => item.id == saved.id);
        if (index < 0) {
          _products = [..._products, saved];
        } else {
          _products[index] = saved;
        }
        _isSavingProduct = false;
      });
      _showMessage(product == null ? 'Perfume added.' : 'Perfume updated.');
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isSavingProduct = false);
      _showMessage('Could not save perfume: $error');
    }
  }

  Future<void> _deleteProduct(Perfume product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove perfume?'),
        content: Text('“${product.name}” will be removed from the collection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('REMOVE'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !mounted) return;

    setState(() => _deletingProductIds.add(product.id));
    try {
      await widget.api.deleteAdminProduct(
        token: widget.token,
        productId: product.id,
      );
      if (!mounted) return;
      setState(() {
        _products.removeWhere((item) => item.id == product.id);
        _deletingProductIds.remove(product.id);
      });
      _showMessage('Perfume removed.');
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _deletingProductIds.remove(product.id));
      _showMessage('Could not remove perfume: $error');
    }
  }

  Future<void> _changeOrderStatus(AdminOrder order, String status) async {
    setState(() => _updatingOrderId = order.id);
    try {
      final updated = await widget.api.updateAdminOrderStatus(
        token: widget.token,
        orderId: order.id,
        status: status,
      );
      if (!mounted) return;
      setState(() {
        final index = _orders.indexWhere((item) => item.id == updated.id);
        if (index >= 0) _orders[index] = updated;
        _updatingOrderId = null;
      });
      _showMessage('Order status updated.');
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _updatingOrderId = null);
      _showMessage('Could not update order status: $error');
    }
  }

  void _showMessage(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ABAQ ADMIN',
          style: TextStyle(fontSize: 11, letterSpacing: 2),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'PRODUCTS'),
            Tab(text: 'ORDERS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildProductsTab(palette), _buildOrdersTab(palette)],
      ),
      floatingActionButton: _tabs.index == 0
          ? FloatingActionButton.extended(
              onPressed: _isSavingProduct ? null : () => _showProductForm(),
              icon: const Icon(Icons.add),
              label: const Text('ADD PERFUME'),
            )
          : null,
    );
  }

  Widget _buildProductsTab(AbaqPalette palette) {
    if (_isLoadingProducts) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_productsError != null) {
      return _LoadError(message: _productsError!, onRetry: _loadProducts);
    }
    if (_products.isEmpty) {
      return _EmptyState(
        icon: Icons.spa_outlined,
        message: 'Your collection is waiting for its first fragrance.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final product = _products[index];
          return Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 5,
              ),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                  width: 52,
                  height: 58,
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: palette.surfaceMuted,
                      child: Icon(Icons.spa_outlined, color: palette.accent),
                    ),
                  ),
                ),
              ),
              title: Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                '${product.category}  ·  \$${product.price.toStringAsFixed(2)}',
                style: TextStyle(color: palette.secondaryText, fontSize: 11),
              ),
              trailing: _deletingProductIds.contains(product.id)
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : PopupMenuButton<String>(
                      tooltip: 'Manage ${product.name}',
                      onSelected: (action) {
                        if (action == 'edit') _showProductForm(product);
                        if (action == 'delete') _deleteProduct(product);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit perfume'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Remove perfume'),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrdersTab(AbaqPalette palette) {
    if (_isLoadingOrders) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ordersError != null) {
      return _LoadError(message: _ordersError!, onRetry: _loadOrders);
    }
    if (_orders.isEmpty) {
      return _EmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'Customer orders will appear here.',
      );
    }
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = _orders[index];
          final date = MaterialLocalizations.of(
            context,
          ).formatMediumDate(order.invoice.createdAt.toLocal());
          return Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.invoice.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${order.invoice.customer.name}  ·  $date',
                  style: TextStyle(color: palette.secondaryText, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  '${order.invoice.items.length} ${order.invoice.items.length == 1 ? 'item' : 'items'}  ·  \$${order.invoice.totalAmount.toStringAsFixed(2)}  ·  ${order.invoice.paymentMethod}',
                  style: TextStyle(color: palette.text, fontSize: 12),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 17,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Update status',
                      style: TextStyle(
                        color: palette.secondaryText,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    if (_updatingOrderId == order.id)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      DropdownButton<String>(
                        value: _statuses.contains(order.status)
                            ? order.status
                            : 'Pending',
                        underline: const SizedBox.shrink(),
                        borderRadius: BorderRadius.circular(10),
                        items: _statuses
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(
                                  status,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (status) {
                          if (status != null && status != order.status) {
                            _changeOrderStatus(order, status);
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.product});

  final Perfume? product;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  late final TextEditingController _price;
  late final TextEditingController _imageUrl;
  late final TextEditingController _rating;
  bool _isBestseller = false;
  bool _isNew = false;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _brand = TextEditingController(text: product?.brand ?? 'Abaq Atelier');
    _category = TextEditingController(text: product?.category ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _notes = TextEditingController(text: product?.notes.join(', ') ?? '');
    _price = TextEditingController(text: product?.price.toString() ?? '');
    _imageUrl = TextEditingController(text: product?.imageUrl ?? '');
    _rating = TextEditingController(text: product?.rating.toString() ?? '4.5');
    _isBestseller = product?.isBestseller ?? false;
    _isNew = product?.isNew ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _category.dispose();
    _description.dispose();
    _notes.dispose();
    _price.dispose();
    _imageUrl.dispose();
    _rating.dispose();
    super.dispose();
  }

  String? _required(String? value, {int minimum = 1}) {
    if (value == null || value.trim().length < minimum) {
      return 'Enter at least $minimum characters.';
    }
    return null;
  }

  String? _validateAmount(String? value, {required bool allowZero}) {
    final amount = double.tryParse(value ?? '');
    if (amount == null ||
        !amount.isFinite ||
        (allowZero ? amount < 0 || amount > 5 : amount <= 0)) {
      return allowZero ? 'Enter a rating from 0 to 5.' : 'Enter a valid price.';
    }
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(<String, Object?>{
      'name': _name.text.trim(),
      'brand': _brand.text.trim(),
      'category': _category.text.trim(),
      'description': _description.text.trim(),
      'notes': _notes.text
          .split(',')
          .map((note) => note.trim())
          .where((note) => note.isNotEmpty)
          .toList(),
      'price': double.parse(_price.text.trim()),
      'imageUrl': _imageUrl.text.trim(),
      'rating': double.parse(_rating.text.trim()),
      'isBestseller': _isBestseller,
      'isNew': _isNew,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product == null ? 'Add perfume' : 'Edit perfume'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const ValueKey('admin-product-name'),
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (value) => _required(value, minimum: 2),
                ),
                TextFormField(
                  key: const ValueKey('admin-product-brand'),
                  controller: _brand,
                  decoration: const InputDecoration(labelText: 'Brand'),
                  validator: (value) => _required(value, minimum: 2),
                ),
                TextFormField(
                  key: const ValueKey('admin-product-category'),
                  controller: _category,
                  decoration: const InputDecoration(
                    labelText: 'Category (e.g. Oud)',
                  ),
                  validator: (value) => _required(value, minimum: 2),
                ),
                TextFormField(
                  key: const ValueKey('admin-product-price'),
                  controller: _price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Price (USD)'),
                  validator: (value) =>
                      _validateAmount(value, allowZero: false),
                ),
                TextFormField(
                  key: const ValueKey('admin-product-rating'),
                  controller: _rating,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Rating (0–5)'),
                  validator: (value) => _validateAmount(value, allowZero: true),
                ),
                TextFormField(
                  key: const ValueKey('admin-product-image'),
                  controller: _imageUrl,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                  validator: (value) {
                    final uri = Uri.tryParse(value?.trim() ?? '');
                    if (uri == null ||
                        !uri.hasAuthority ||
                        !const ['http', 'https'].contains(uri.scheme)) {
                      return 'Enter a complete image URL.';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  key: const ValueKey('admin-product-description'),
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) => _required(value, minimum: 10),
                ),
                TextFormField(
                  key: const ValueKey('admin-product-notes'),
                  controller: _notes,
                  decoration: const InputDecoration(
                    labelText: 'Notes (comma separated)',
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _isBestseller,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Bestseller'),
                  onChanged: (value) =>
                      setState(() => _isBestseller = value ?? false),
                ),
                CheckboxListTile(
                  value: _isNew,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('New arrival'),
                  onChanged: (value) => setState(() => _isNew = value ?? false),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.product == null ? 'ADD' : 'SAVE'),
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, color: palette.accent, size: 34),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: palette.accent),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.accentSoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: palette.accent,
          fontSize: 9,
          letterSpacing: 0.7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
