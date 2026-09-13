class ApiConfig {
  ApiConfig._();

  // Puede cambiarse al ejecutar Flutter:
  // flutter run --dart-define=API_BASE_URL=http://192.168.100.34:5000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.100.34:5000',
  );

  static const bool isProduction = bool.fromEnvironment(
    'PRODUCTION',
    defaultValue: false,
  );

  static const Duration connectTimeout = Duration(seconds: 8);
  static const Duration receiveTimeout = Duration(seconds: 10);
  static const Duration sendTimeout = Duration(seconds: 10);

  static const String loginEndpoint = '/api/auth/login';
  static const String refreshEndpoint = '/api/auth/refresh';
  static const String tasksEndpoint = '/api/tareas';

  static void validate() {
    if (isProduction && !baseUrl.startsWith('https://')) {
      throw StateError('En producción la API debe usar HTTPS.');
    }
  }
}
