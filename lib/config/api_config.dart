class ApiConfig {
  ApiConfig._();

  // Teléfono físico conectado al mismo Wi-Fi que la PC.
  static const String baseUrl = 'http://192.168.100.34:5000';

  static const Duration connectTimeout =
      Duration(seconds: 5);

  static const Duration receiveTimeout =
      Duration(seconds: 10);

  static const Duration sendTimeout =
      Duration(seconds: 10);

  static const String loginEndpoint =
      '/api/auth/login';

  static const String refreshEndpoint =
      '/api/auth/refresh';

  static const String tasksEndpoint =
      '/api/tareas';
}