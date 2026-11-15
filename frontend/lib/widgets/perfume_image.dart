import 'package:flutter/material.dart';

import '../theme/abaq_theme.dart';

class PerfumeImage extends StatelessWidget {
  const PerfumeImage({
    required this.imageUrl,
    required this.height,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String imageUrl;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => Container(
          color: palette.surfaceMuted,
          alignment: Alignment.center,
          child: Icon(Icons.spa_outlined, color: palette.accent, size: 40),
        ),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: palette.surfaceMuted,
            alignment: Alignment.center,
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.accent,
              ),
            ),
          );
        },
      ),
    );
  }
}
