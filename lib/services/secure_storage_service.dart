import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const FlutterSecureStorage _storage =
      FlutterSecureStorage();

  static const String _accessTokenKey =
      'access_token';

  static const String _refreshTokenKey =
      'refresh_token';

  // ============================================================
  // ACCESS TOKEN
  // ============================================================

  static Future<void> saveAccessToken(
    String token,
  ) async {
    await _storage.write(
      key: _accessTokenKey,
      value: token,
    );
  }

  static Future<String?> getAccessToken() async {
    return await _storage.read(
      key: _accessTokenKey,
    );
  }

  // ============================================================
  // REFRESH TOKEN
  // ============================================================

  static Future<void> saveRefreshToken(
    String token,
  ) async {
    await _storage.write(
      key: _refreshTokenKey,
      value: token,
    );
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(
      key: _refreshTokenKey,
    );
  }

  // ============================================================
  // GUARDAR AMBOS
  // ============================================================

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await saveAccessToken(accessToken);
    await saveRefreshToken(refreshToken);
  }

  // ============================================================
  // LIMPIAR SESIÓN
  // ============================================================

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}