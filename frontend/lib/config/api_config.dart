import 'package:flutter/foundation.dart';

const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

abstract final class ApiConfig {
  static Uri get baseUri {
    if (_configuredApiBaseUrl.isEmpty) {
      if (kReleaseMode) {
        throw StateError('API_BASE_URL must be set for release builds.');
      }

      final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : 'localhost';
      return Uri(scheme: 'http', host: host, port: 3000, path: '/api/');
    }

    final uri = Uri.tryParse(_configuredApiBaseUrl);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw StateError(
        'API_BASE_URL must be an absolute HTTP(S) URL ending in /api/.',
      );
    }

    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    if (!path.endsWith('/api/')) {
      throw StateError(
        'API_BASE_URL must be an absolute HTTP(S) URL ending in /api/.',
      );
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('API_BASE_URL must use HTTPS in release builds.');
    }

    return uri.replace(path: path);
  }
}
