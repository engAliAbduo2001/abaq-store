import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';

class AuthSessionStore {
  static const sessionKey = 'abaq.auth.session.v1';

  Future<AuthSession?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(sessionKey);
    if (encoded == null) return null;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        throw const FormatException('Saved account session is not an object.');
      }
      return AuthSession.fromJson(Map<String, dynamic>.from(decoded));
    } on FormatException catch (error) {
      await preferences.remove(sessionKey);
      throw FormatException(
        'The saved account session was invalid and has been cleared: $error',
      );
    }
  }

  Future<void> save(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      sessionKey,
      jsonEncode(session.toJson()),
    );
    if (!saved) {
      throw Exception('The account session could not be saved on this device.');
    }
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(sessionKey);
  }
}
