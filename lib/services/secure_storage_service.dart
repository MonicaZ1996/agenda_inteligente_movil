import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'auth_token';

  // Guardar token cifrado
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  // Leer token
  static Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  // Borrar credenciales al cerrar sesión
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}