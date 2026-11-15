import 'package:flutter/material.dart';

import '../models/perfume.dart';
import '../theme/abaq_theme.dart';
import 'perfume_image.dart';

class PerfumeCard extends StatelessWidget {
  const PerfumeCard({
    required this.perfume,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onAdd,
    super.key,
  });

  final Perfume perfume;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Material(
      color: palette.surface,
      elevation: Theme.of(context).brightness == Brightness.light ? 1 : 0,
      shadowColor: palette.shadow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('product-${perfume.id}'),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PerfumeImage(imageUrl: perfume.imageUrl, height: 190),
                  if (perfume.badge case final badge?)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: palette.accentText,
                            fontSize: 9,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 7,
                    right: 7,
                    child: Material(
                      color: palette.surface.withValues(alpha: 0.94),
                      shape: CircleBorder(
                        side: BorderSide(color: palette.border),
                      ),
                      child: IconButton(
                        key: ValueKey('favorite-${perfume.id}'),
                        onPressed: onToggleFavorite,
                        tooltip: isFavorite
                            ? 'Remove ${perfume.name} from wishlist'
                            : 'Add ${perfume.name} to wishlist',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 38,
                          height: 38,
                        ),
                        iconSize: 19,
                        color: isFavorite ? palette.danger : palette.text,
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 11, 9, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    perfume.brand.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.secondaryText,
                      fontSize: 9,
                      letterSpacing: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    perfume.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 5,
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
                            fontSize: 14,
                          ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_shopping_cart, size: 13),
                        label: const Text('ADD'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 30),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
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
