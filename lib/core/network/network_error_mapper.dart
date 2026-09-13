import 'package:dio/dio.dart';

class NetworkErrorMapper {
  NetworkErrorMapper._();

  static String toDomainMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return 'La conexión tardó demasiado. Intenta nuevamente.';

      case DioExceptionType.connectionError:
        return 'Sin conexión con el servidor. Se usarán los datos locales disponibles.';

      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        final data = error.response?.data;

        if (status == 422) {
          if (data is Map && data['errors'] is Map) {
            final errors =
                Map<String, dynamic>.from(data['errors'] as Map);

            return errors.values
                .map((e) => e.toString())
                .join('\n');
          }

          return 'Revisa los datos ingresados.';
        }

        if (status == 401 || status == 403) {
          return 'La sesión no es válida o ha expirado.';
        }

        if (status >= 400 && status < 500) {
          return 'La solicitud contiene datos no válidos.';
        }

        if (status >= 500) {
          return 'El servidor presenta un problema temporal.';
        }

        return 'No fue posible completar la solicitud.';

      case DioExceptionType.cancel:
        return 'La solicitud fue cancelada.';

      case DioExceptionType.badCertificate:
        return 'No se pudo verificar la seguridad del servidor.';

      case DioExceptionType.unknown:
        return 'Ocurrió un error de red inesperado.';
    }
  }
}