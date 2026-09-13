import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../config/api_config.dart';
import '../../models/tarea.dart';

class TaskRemoteDataSource {
  final Dio _dio = DioClient.instance.dio;

  /// Obtiene el listado de tareas desde el backend.
  Future<List<Tarea>> getTasks() async {
    final response = await _dio.get(
      ApiConfig.tasksEndpoint,
    );

    final data = response.data;

    if (data is List) {
      return data
          .map(
            (item) => Tarea.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    if (data is Map<String, dynamic> &&
        data['tareas'] is List) {
      return (data['tareas'] as List)
          .map(
            (item) => Tarea.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    return [];
  }

  /// Crea una tarea en el backend.
  Future<Tarea> createTask(
    Map<String, dynamic> task,
  ) async {
    final response = await _dio.post(
      ApiConfig.tasksEndpoint,
      data: task,
    );

    final data =
        Map<String, dynamic>.from(response.data);

    // El backend devuelve la tarea dentro
    // de la propiedad "tarea".
    if (data['tarea'] is Map) {
      return Tarea.fromJson(
        Map<String, dynamic>.from(
          data['tarea'],
        ),
      );
    }

    // Compatibilidad por si el backend
    // devuelve directamente la tarea.
    return Tarea.fromJson(data);
  }
}