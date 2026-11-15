import 'package:flutter/material.dart';

import '../models/perfume.dart';
import '../theme/abaq_theme.dart';
import '../widgets/perfume_card.dart';
import '../widgets/perfume_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.perfumes,
    required this.catalogError,
    required this.isLoadingCatalog,
    required this.onRetryCatalog,
    required this.favoriteIds,
    required this.favoriteCount,
    required this.cartCount,
    required this.onOpenWishlist,
    required this.onOpenCart,
    required this.onOpenAccount,
    required this.isRestoringSession,
    required this.isDark,
    required this.onToggleTheme,
    required this.onOpenDetails,
    required this.onAddToCart,
    required this.onToggleFavorite,
    super.key,
  });

  final List<Perfume> perfumes;
  final String? catalogError;
  final bool isLoadingCatalog;
  final VoidCallback onRetryCatalog;
  final Set<String> favoriteIds;
  final int favoriteCount;
  final int cartCount;
  final VoidCallback onOpenWishlist;
  final VoidCallback onOpenCart;
  final VoidCallback onOpenAccount;
  final bool isRestoringSession;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final ValueChanged<Perfume> onOpenDetails;
  final ValueChanged<Perfume> onAddToCart;
  final ValueChanged<Perfume> onToggleFavorite;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _categories = ['All', 'Oud', 'Oriental', 'French'];

  String _selectedCategory = 'All';
  String _searchQuery = '';

  List<Perfume> get _visiblePerfumes {
    final query = _searchQuery.trim().toLowerCase();
    return widget.perfumes.where((perfume) {
      final matchesCategory =
          _selectedCategory == 'All' || perfume.category == _selectedCategory;
      final searchable =
          '${perfume.name} ${perfume.brand} ${perfume.category} ${perfume.notes.join(' ')}'
              .toLowerCase();
      return matchesCategory && (query.isEmpty || searchable.contains(query));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 18,
        titleSpacing: 6,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A B A Q',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
              ),
            ),
            Text(
              'عبق  ·  THE ART OF SCENT',
              style: TextStyle(
                color: palette.secondaryText,
                fontSize: 8,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('theme-toggle'),
            onPressed: widget.onToggleTheme,
            tooltip: widget.isDark
                ? 'Switch to light mode'
                : 'Switch to dark mode',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 44),
            icon: Icon(
              widget.isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 20,
              color: palette.accent,
            ),
          ),
          IconButton(
            key: const ValueKey('open-wishlist'),
            onPressed: widget.onOpenWishlist,
            tooltip: 'Wishlist',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 44),
            icon: Badge(
              isLabelVisible: widget.favoriteCount > 0,
              label: Text('${widget.favoriteCount}'),
              backgroundColor: palette.accent,
              textColor: palette.accentText,
              child: const Icon(Icons.favorite_border),
            ),
          ),
          IconButton(
            key: const ValueKey('open-cart'),
            onPressed: widget.onOpenCart,
            tooltip: 'Shopping bag',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 44),
            icon: Badge(
              isLabelVisible: widget.cartCount > 0,
              label: Text('${widget.cartCount}'),
              backgroundColor: palette.accent,
              textColor: palette.accentText,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
          ),
          IconButton(
            key: const ValueKey('open-account'),
            onPressed: widget.isRestoringSession ? null : widget.onOpenAccount,
            tooltip: widget.isRestoringSession
                ? 'Restoring session'
                : 'Account',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 38, height: 44),
            icon: widget.isRestoringSession
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _HeroBanner(onExplore: () => _selectCategory('All')),
          const SizedBox(height: 28),
          if (widget.catalogError != null)
            _CatalogFallbackNotice(
              message: widget.catalogError!,
              isLoading: widget.isLoadingCatalog,
              onRetry: widget.onRetryCatalog,
            ),
          TextField(
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search scents, notes, or houses',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'Explore by mood',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final selected = category == _selectedCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => _selectCategory(category),
                  selectedColor: palette.accentSoft,
                  backgroundColor: palette.surface,
                  labelStyle: TextStyle(
                    color: selected ? palette.text : palette.secondaryText,
                    fontSize: 12,
                  ),
                  side: BorderSide(
                    color: selected ? palette.accent : palette.border,
                  ),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedCategory == 'All'
                      ? 'The collection'
                      : '$_selectedCategory fragrances',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                '${_visiblePerfumes.length} SCENTS',
                style: TextStyle(
                  color: palette.secondaryText,
                  fontSize: 9,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_visiblePerfumes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 38),
              child: Center(child: Text('No fragrances match your search.')),
            )
          else
            GridView.builder(
              itemCount: _visiblePerfumes.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 13,
                childAspectRatio: 0.66,
              ),
              itemBuilder: (context, index) {
                final perfume = _visiblePerfumes[index];
                return PerfumeCard(
                  perfume: perfume,
                  isFavorite: widget.favoriteIds.contains(perfume.id),
                  onTap: () => widget.onOpenDetails(perfume),
                  onToggleFavorite: () => widget.onToggleFavorite(perfume),
                  onAdd: () {
                    widget.onAddToCart(perfume);
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('${perfume.name} added to your bag'),
                        duration: const Duration(milliseconds: 1200),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  void _selectCategory(String category) {
    setState(() => _selectedCategory = category);
  }
}

class _CatalogFallbackNotice extends StatelessWidget {
  const _CatalogFallbackNotice({
    required this.message,
    required this.isLoading,
    required this.onRetry,
  });

  final String message;
  final bool isLoading;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, color: palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Showing the saved collection. The live catalog is unavailable.',
              style: TextStyle(fontSize: 12, color: palette.text),
            ),
          ),
          TextButton(
            onPressed: isLoading ? null : onRetry,
            child: Text(isLoading ? 'RETRYING' : 'RETRY'),
          ),
          Tooltip(
            message: message,
            child: Icon(
              Icons.info_outline,
              size: 18,
              color: palette.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 224,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PerfumeImage(
              imageUrl:
                  'https://images.unsplash.com/photo-1615634260167-c8cdede054de?auto=format&fit=crop&w=1400&q=85',
              height: 224,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF08080B).withValues(alpha: 0.88),
                    const Color(0xFF08080B).withValues(alpha: 0.46),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SCENT, REIMAGINED',
                    style: TextStyle(
                      color: palette.accent,
                      fontSize: 9,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'A world of\nquiet luxury.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 29,
                      height: 1.12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 15),
                  OutlinedButton(
                    onPressed: onExplore,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 9,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    child: const Text('DISCOVER ABAQ'),
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
