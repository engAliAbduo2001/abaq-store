import 'package:flutter/material.dart';

import '../models/perfume.dart';
import '../theme/abaq_theme.dart';
import '../widgets/perfume_image.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({
    required this.catalog,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.onAddToCart,
    required this.onOpenCart,
    super.key,
  });

  final List<Perfume> catalog;
  final Set<String> favoriteIds;
  final ValueChanged<Perfume> onToggleFavorite;
  final ValueChanged<Perfume> onAddToCart;
  final VoidCallback onOpenCart;

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Perfume> get _savedPerfumes => widget.catalog
      .where((perfume) => widget.favoriteIds.contains(perfume.id))
      .toList();

  void _remove(Perfume perfume) {
    widget.onToggleFavorite(perfume);
    setState(() {});
  }

  void _moveToBag(Perfume perfume) {
    widget.onAddToCart(perfume);
    widget.onToggleFavorite(perfume);
    setState(() {});
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text('${perfume.name} moved to your bag'),
        action: SnackBarAction(label: 'VIEW BAG', onPressed: widget.onOpenCart),
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    final perfumes = _savedPerfumes;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'YOUR WISHLIST',
          style: TextStyle(fontSize: 11, letterSpacing: 2),
        ),
        centerTitle: true,
        actions: [
          if (perfumes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text(
                  '${perfumes.length} SAVED',
                  style: TextStyle(
                    color: palette.secondaryText,
                    fontSize: 9,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: perfumes.isEmpty
          ? _EmptyWishlist(onExplore: () => Navigator.of(context).pop())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              itemCount: perfumes.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final perfume = perfumes[index];
                return _WishlistItem(
                  perfume: perfume,
                  onRemove: () => _remove(perfume),
                  onMoveToBag: () => _moveToBag(perfume),
                );
              },
            ),
    );
  }
}

class _WishlistItem extends StatelessWidget {
  const _WishlistItem({
    required this.perfume,
    required this.onRemove,
    required this.onMoveToBag,
  });

  final Perfume perfume;
  final VoidCallback onRemove;
  final VoidCallback onMoveToBag;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Material(
      key: ValueKey('wishlist-${perfume.id}'),
      color: palette.surface,
      elevation: Theme.of(context).brightness == Brightness.light ? 1 : 0,
      shadowColor: palette.shadow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                width: 92,
                child: PerfumeImage(imageUrl: perfume.imageUrl, height: 118),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              perfume.brand.toUpperCase(),
                              style: TextStyle(
                                color: palette.secondaryText,
                                fontSize: 9,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              perfume.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: ValueKey('remove-favorite-${perfume.id}'),
                        onPressed: onRemove,
                        tooltip: 'Remove from wishlist',
                        visualDensity: VisualDensity.compact,
                        iconSize: 20,
                        color: palette.danger,
                        icon: const Icon(Icons.favorite),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '\$${perfume.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: palette.accentText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: ValueKey('move-to-bag-${perfume.id}'),
                      onPressed: onMoveToBag,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide(color: palette.border),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                      label: const Text(
                        'MOVE TO BAG',
                        style: TextStyle(fontSize: 10, letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWishlist extends StatelessWidget {
  const _EmptyWishlist({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.favorite_border,
                color: palette.accent,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Your wishlist awaits',
              style: TextStyle(
                color: palette.text,
                fontSize: 23,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Save the scents you love and return to them anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.secondaryText, height: 1.5),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: onExplore,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
              ),
              child: const Text(
                'EXPLORE FRAGRANCES',
                style: TextStyle(fontSize: 10, letterSpacing: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
