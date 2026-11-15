import 'package:flutter/material.dart';

import '../models/perfume.dart';
import '../theme/abaq_theme.dart';
import '../widgets/perfume_image.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({
    required this.perfume,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onAddToCart,
    super.key,
  });

  final Perfume perfume;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToCart;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late bool _isFavorite = widget.isFavorite;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'THE FRAGRANCE',
          style: TextStyle(fontSize: 11, letterSpacing: 2),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            key: const ValueKey('detail-favorite'),
            onPressed: () {
              widget.onToggleFavorite();
              setState(() => _isFavorite = !_isFavorite);
            },
            tooltip: _isFavorite ? 'Remove from wishlist' : 'Add to wishlist',
            color: _isFavorite ? palette.danger : palette.text,
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PerfumeImage(imageUrl: widget.perfume.imageUrl, height: 340),
          ),
          const SizedBox(height: 24),
          Text(
            widget.perfume.brand.toUpperCase(),
            style: TextStyle(
              color: palette.secondaryText,
              fontSize: 10,
              letterSpacing: 1.7,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            widget.perfume.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            widget.perfume.description,
            style: TextStyle(color: palette.secondaryText, height: 1.6),
          ),
          const SizedBox(height: 24),
          const Text(
            'THE NOTES',
            style: TextStyle(fontSize: 10, letterSpacing: 1.7),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.perfume.notes
                .map(
                  (note) => Chip(
                    label: Text(note),
                    backgroundColor: palette.surfaceMuted,
                    side: BorderSide(color: palette.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '\$${widget.perfume.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: palette.accentText,
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('add-to-bag'),
                onPressed: () {
                  widget.onAddToCart();
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${widget.perfume.name} added to your bag'),
                      duration: const Duration(milliseconds: 1200),
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('ADD TO BAG'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
