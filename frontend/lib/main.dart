import 'dart:async';

import 'package:flutter/material.dart';

import 'data/perfume_catalog.dart';
import 'models/auth_session.dart';
import 'models/perfume.dart';
import 'services/abaq_api.dart';
import 'screens/auth_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/product_details_screen.dart';
import 'screens/wishlist_screen.dart';
import 'services/auth_session_store.dart';
import 'services/payment_gateway.dart';
import 'theme/abaq_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PaymentGateway.initialize();
  runApp(const AbaqApp());
}

class AbaqApp extends StatefulWidget {
  const AbaqApp({this.api, this.sessionStore, super.key});

  final AbaqApi? api;
  final AuthSessionStore? sessionStore;

  @override
  State<AbaqApp> createState() => _AbaqAppState();
}

class _AbaqAppState extends State<AbaqApp> {
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Abaq | Luxury Fragrance',
      debugShowCheckedModeBanner: false,
      theme: AbaqTheme.noirIvory,
      darkTheme: AbaqTheme.midnightGold,
      themeMode: _themeMode,
      home: AbaqStore(
        api: widget.api,
        sessionStore: widget.sessionStore,
        isDark: _themeMode == ThemeMode.dark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class AbaqStore extends StatefulWidget {
  const AbaqStore({
    this.api,
    this.sessionStore,
    required this.isDark,
    required this.onToggleTheme,
    super.key,
  });

  final AbaqApi? api;
  final AuthSessionStore? sessionStore;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<AbaqStore> createState() => _AbaqStoreState();
}

class _AbaqStoreState extends State<AbaqStore> {
  late final AbaqApi _api = widget.api ?? AbaqApi();
  late final AuthSessionStore _sessionStore =
      widget.sessionStore ?? AuthSessionStore();
  final Map<String, int> _cart = {};
  final Set<String> _favoriteIds = {};
  List<Perfume> _perfumes = perfumeCatalog;
  bool _isLoadingCatalog = true;
  String? _catalogError;
  AuthSession? _session;
  bool _isRestoringSession = true;
  bool _handlingRejectedSession = false;
  Future<void> _wishlistSaveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _api.onUnauthorized = _onUnauthorized;
    _restoreSession();
    _loadPerfumes();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _loadPerfumes() async {
    setState(() => _isLoadingCatalog = true);
    try {
      final perfumes = await _api.fetchPerfumes();
      if (!mounted) return;
      setState(() {
        _perfumes = perfumes;
        _catalogError = null;
        _isLoadingCatalog = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _perfumes = perfumeCatalog;
        _catalogError = error.toString();
        _isLoadingCatalog = false;
      });
    }
  }

  Future<void> _restoreSession() async {
    try {
      final savedSession = await _sessionStore.load();
      if (savedSession == null) return;

      try {
        final user = await _api.fetchCurrentUser(savedSession.token);
        final restoredSession = AuthSession(
          token: savedSession.token,
          user: user,
        );
        await _sessionStore.save(restoredSession);
        if (!mounted) return;
        setState(() => _session = restoredSession);
        unawaited(_restoreWishlist(restoredSession));
      } on AbaqApiException catch (error) {
        if (error.statusCode == 401) {
          await _sessionStore.clear();
          if (!mounted) return;
          setState(() => _session = null);
          _scheduleLoginPrompt(
            'Your saved session expired. Please sign in again.',
          );
        } else {
          if (!mounted) return;
          setState(() => _session = savedSession);
          _showSessionNotice(
            'Your saved account could not be verified right now. '
            'Account actions may require signing in again.',
          );
        }
      } on Exception {
        if (!mounted) return;
        setState(() => _session = savedSession);
        _showSessionNotice(
          'Your saved account could not be verified right now. '
          'Account actions may require signing in again.',
        );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      _showSessionNotice('Could not restore your saved account: $error');
    } finally {
      if (mounted) setState(() => _isRestoringSession = false);
    }
  }

  void _onUnauthorized() {
    final token = _session?.token;
    if (token == null || _handlingRejectedSession) return;
    _handlingRejectedSession = true;
    unawaited(_expireSession(token));
  }

  Future<void> _expireSession(String token) async {
    String? clearError;
    try {
      await _sessionStore.clear();
    } on Exception catch (error) {
      clearError = error.toString();
    }

    if (!mounted || _session?.token != token) {
      _handlingRejectedSession = false;
      return;
    }
    setState(() {
      _session = null;
      _favoriteIds.clear();
    });
    _handlingRejectedSession = false;
    _scheduleLoginPrompt(
      clearError == null
          ? 'Your session expired. Please sign in again.'
          : 'Your session expired, but its local copy could not be cleared: '
                '$clearError',
    );
  }

  void _scheduleLoginPrompt([String? notice]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _session != null) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => _buildAuthScreen()),
        (route) => route.isFirst,
      );
      if (notice != null) _showSessionNotice(notice);
    });
  }

  void _showSessionNotice(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    });
  }

  int get _cartCount =>
      _cart.values.fold(0, (total, quantity) => total + quantity);

  int get _favoriteCount =>
      _perfumes.where((perfume) => _favoriteIds.contains(perfume.id)).length;

  void _openAccount() {
    final session = _session;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => session == null
            ? _buildAuthScreen()
            : ProfileScreen(
                api: _api,
                session: session,
                onLogout: () => _logout(session.token),
              ),
      ),
    );
  }

  AuthScreen _buildAuthScreen() =>
      AuthScreen(api: _api, onAuthenticated: _onAuthenticated);

  Future<void> _onAuthenticated(AuthSession session) async {
    await _sessionStore.save(session);
    if (!mounted) return;
    setState(() => _session = session);
    Navigator.of(context).pop();
    unawaited(_restoreWishlist(session));
  }

  Future<void> _restoreWishlist(AuthSession session) async {
    try {
      final savedIds = await _api.fetchUserWishlist(
        userId: session.user.id,
        token: session.token,
      );
      if (!mounted || _session?.token != session.token) return;

      final mergedIds = <String>{...savedIds, ..._favoriteIds};
      final serverIds = savedIds.toSet();
      final hasGuestFavorites =
          mergedIds.length != serverIds.length ||
          !serverIds.containsAll(mergedIds);
      setState(() {
        _favoriteIds
          ..clear()
          ..addAll(mergedIds);
      });
      if (hasGuestFavorites) _queueWishlistSave(session);
    } on Exception catch (error) {
      if (!mounted || _session?.token != session.token) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not sync your wishlist: $error'),
          duration: const Duration(milliseconds: 1200),
        ),
      );
    }
  }

  void _queueWishlistSave(AuthSession session) {
    final productIds = List<String>.unmodifiable(_favoriteIds);
    _wishlistSaveQueue = _wishlistSaveQueue
        .then((_) async {
          if (!mounted || _session?.token != session.token) return;
          await _api.saveUserWishlist(
            userId: session.user.id,
            token: session.token,
            productIds: productIds,
          );
        })
        .catchError((Object error) {
          if (!mounted || _session?.token != session.token) return;
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Could not save your wishlist: $error'),
              duration: const Duration(milliseconds: 1200),
            ),
          );
        });
  }

  Future<bool> _logout(String token) async {
    await _sessionStore.clear();
    setState(() {
      _session = null;
      _favoriteIds.clear();
    });
    try {
      await _api.logout(token);
      return true;
    } on Exception {
      return false;
    }
  }

  void _addToCart(Perfume perfume) {
    setState(() {
      _cart.update(perfume.id, (quantity) => quantity + 1, ifAbsent: () => 1);
    });
  }

  void _setQuantity(String perfumeId, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cart.remove(perfumeId);
      } else {
        _cart[perfumeId] = quantity;
      }
    });
  }

  void _toggleFavorite(Perfume perfume) {
    setState(() {
      if (!_favoriteIds.add(perfume.id)) {
        _favoriteIds.remove(perfume.id);
      }
    });
    final session = _session;
    if (session != null) _queueWishlistSave(session);
  }

  void _openDetails(Perfume perfume) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductDetailsScreen(
          perfume: perfume,
          isFavorite: _favoriteIds.contains(perfume.id),
          onToggleFavorite: () => _toggleFavorite(perfume),
          onAddToCart: () => _addToCart(perfume),
        ),
      ),
    );
  }

  void _openWishlist() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WishlistScreen(
          catalog: _perfumes,
          favoriteIds: _favoriteIds,
          onToggleFavorite: _toggleFavorite,
          onAddToCart: _addToCart,
          onOpenCart: _openCart,
        ),
      ),
    );
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CartScreen(
          cart: _cart,
          catalog: _perfumes,
          api: _api,
          session: _session,
          onQuantityChanged: _setQuantity,
          onOrderPlaced: () => setState(_cart.clear),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      perfumes: _perfumes,
      catalogError: _catalogError,
      isLoadingCatalog: _isLoadingCatalog,
      onRetryCatalog: _loadPerfumes,
      favoriteIds: _favoriteIds,
      favoriteCount: _favoriteCount,
      cartCount: _cartCount,
      onOpenWishlist: _openWishlist,
      onOpenCart: _openCart,
      onOpenAccount: _openAccount,
      isRestoringSession: _isRestoringSession,
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
      onOpenDetails: _openDetails,
      onAddToCart: _addToCart,
      onToggleFavorite: _toggleFavorite,
    );
  }
}
