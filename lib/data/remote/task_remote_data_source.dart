import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../../config/api_config.dart';
import '../../models/tarea.dart';

class TaskRemoteDataSource {
  final Dio _dio = DioClient.instance.dio;

  Future<List<Tarea>> getTasks() async {
    final response = await _dio.get(ApiConfig.tasksEndpoint);
    final data = response.data;

    if (data is List) {
      return data
          .map((item) => Tarea.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    if (data is Map && data['tareas'] is List) {
      return (data['tareas'] as List)
          .map((item) => Tarea.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    return [];
  }

  Future<Tarea> createTask(Map<String, dynamic> task) async {
    final response = await _dio.post(
      ApiConfig.tasksEndpoint,
      data: task,
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    final taskJson = data['tarea'] is Map
        ? Map<String, dynamic>.from(data['tarea'] as Map)
        : data;

    return Tarea.fromJson(taskJson);
  }
}
