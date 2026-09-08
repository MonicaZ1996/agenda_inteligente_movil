import 'package:dio/dio.dart';

import '../../config/api_config.dart';
import '../../services/secure_storage_service.dart';

class DioClient {
  static final DioClient instance = DioClient._internal();

  late final Dio dio;

  // Evita que varias peticiones hagan refresh al mismo tiempo.
  Future<String?>? _refreshFuture;

  DioClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        // =========================================================
        // AGREGAR ACCESS TOKEN
        // =========================================================
        onRequest: (options, handler) async {
          final token =
              await SecureStorageService.getAccessToken();

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          handler.next(options);
        },

        // =========================================================
        // MANEJAR ERROR 401
        // =========================================================
        onError: (error, handler) async {
          if (error.response?.statusCode != 401) {
            handler.next(error);
            return;
          }

          // Evitar refresh infinito.
          if (error.requestOptions.extra['retried'] == true) {
            handler.next(error);
            return;
          }

          try {
            final newAccessToken = await _refreshAccessToken();

            if (newAccessToken == null ||
                newAccessToken.isEmpty) {
              handler.next(error);
              return;
            }

            // Marcar la petición para impedir un segundo refresh
            // infinito sobre la misma petición.
            error.requestOptions.extra['retried'] = true;

            error.requestOptions.headers['Authorization'] =
                'Bearer $newAccessToken';

            // Repetir automáticamente la petición original.
            final response =
                await dio.fetch(error.requestOptions);

            handler.resolve(response);
          } on DioException catch (e) {
            handler.next(e);
          } catch (_) {
            handler.next(error);
          }
        },
      ),
    );
  }

  // =============================================================
  // REFRESH TOKEN
  // =============================================================
  Future<String?> _refreshAccessToken() async {
    // Si ya existe un refresh en proceso, reutilizarlo.
    if (_refreshFuture != null) {
      return _refreshFuture;
    }

    _refreshFuture = _performRefresh();

    try {
      return await _refreshFuture;
    } finally {
      _refreshFuture = null;
    }
  }

  // =============================================================
  // REALIZAR REFRESH
  // =============================================================
  Future<String?> _performRefresh() async {
    final refreshToken =
        await SecureStorageService.getRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      await SecureStorageService.clearAll();
      return null;
    }

    // Dio independiente para que el refresh no vuelva
    // a entrar en este mismo interceptor.
    final refreshDio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        sendTimeout: ApiConfig.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    try {
      final response = await refreshDio.post(
        ApiConfig.refreshEndpoint,
        data: {
          'refreshToken': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;

        final newAccessToken =
            data['accessToken'] as String?;

        final newRefreshToken =
            data['refreshToken'] as String?;

        if (newAccessToken == null ||
            newAccessToken.isEmpty) {
          await SecureStorageService.clearAll();
          return null;
        }

        await SecureStorageService.saveAccessToken(
          newAccessToken,
        );

        if (newRefreshToken != null &&
            newRefreshToken.isNotEmpty) {
          await SecureStorageService.saveRefreshToken(
            newRefreshToken,
          );
        }

        return newAccessToken;
      }

      await SecureStorageService.clearAll();
      return null;
    } on DioException {
      await SecureStorageService.clearAll();
      return null;
    } catch (_) {
      await SecureStorageService.clearAll();
      return null;
    } finally {
      refreshDio.close();
    }
  }
}