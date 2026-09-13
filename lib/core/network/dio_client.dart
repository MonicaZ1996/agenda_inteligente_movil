import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../config/api_config.dart';
import '../../services/secure_storage_service.dart';

class DioClient {
  static final DioClient instance = DioClient._internal();

  late final Dio dio;
  Future<String?>? _refreshFuture;

  DioClient._internal() {
    ApiConfig.validate();

    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // 1) Autenticación + renovación de token.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isAuthEndpoint =
              options.path == ApiConfig.loginEndpoint ||
              options.path == ApiConfig.refreshEndpoint;

          if (!isAuthEndpoint) {
            final token = await SecureStorageService.getAccessToken();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final method = request.method.toUpperCase();

          // Reintento de red SOLO para operaciones idempotentes.
          final retryableNetworkError =
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.connectionError ||
              ((error.response?.statusCode ?? 0) >= 500);

          if ((method == 'GET' || method == 'HEAD') &&
              retryableNetworkError &&
              request.extra['networkRetried'] != true) {
            request.extra['networkRetried'] = true;
            await Future<void>.delayed(const Duration(milliseconds: 500));
            try {
              final response = await dio.fetch(request);
              handler.resolve(response);
              return;
            } on DioException catch (e) {
              handler.next(e);
              return;
            }
          }

          if (error.response?.statusCode != 401 ||
              request.path == ApiConfig.loginEndpoint ||
              request.path == ApiConfig.refreshEndpoint) {
            handler.next(error);
            return;
          }

          if (request.extra['authRetried'] == true) {
            handler.next(error);
            return;
          }

          try {
            final newAccessToken = await _refreshAccessToken();
            if (newAccessToken == null || newAccessToken.isEmpty) {
              handler.next(error);
              return;
            }

            request.extra['authRetried'] = true;
            request.headers['Authorization'] = 'Bearer $newAccessToken';

            final response = await dio.fetch(request);
            handler.resolve(response);
          } on DioException catch (e) {
            handler.next(e);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );

    // 2) Registro solo en desarrollo. No imprime encabezados de autorización.
    if (!kReleaseMode) {
      dio.interceptors.add(
        LogInterceptor(
          requestHeader: false,
          responseHeader: false,
          requestBody: true,
          responseBody: false,
          error: true,
          logPrint: (object) => debugPrint(object.toString()),
        ),
      );
    }
  }

  Future<String?> _refreshAccessToken() async {
    if (_refreshFuture != null) return _refreshFuture;

    _refreshFuture = _performRefresh();
    try {
      return await _refreshFuture;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await SecureStorageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final refreshDio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    try {
      final response = await refreshDio.post(
        ApiConfig.refreshEndpoint,
        data: {'refreshToken': refreshToken},
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      final newAccessToken = data['accessToken'] as String?;
      final newRefreshToken = data['refreshToken'] as String?;

      if (newAccessToken == null || newAccessToken.isEmpty) return null;

      await SecureStorageService.saveAccessToken(newAccessToken);
      if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
        await SecureStorageService.saveRefreshToken(newRefreshToken);
      }

      return newAccessToken;
    } on DioException catch (e) {
      // Solo eliminamos la sesión si el servidor rechaza el refresh.
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        await SecureStorageService.clearAll();
      }
      return null;
    } finally {
      refreshDio.close();
    }
  }
}
