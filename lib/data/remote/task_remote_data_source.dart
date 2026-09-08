import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../config/api_config.dart';

class TaskRemoteDataSource {
  final Dio _dio = DioClient.instance.dio;

  Future<List<Map<String, dynamic>>> getTasks() async {
    final response = await _dio.get(
      ApiConfig.tasksEndpoint,
    );

    final data = response.data;

    if (data is List) {
      return data
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    if (data is Map<String, dynamic> &&
        data['tareas'] is List) {
      return (data['tareas'] as List)
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    }

    return [];
  }

  Future<Map<String, dynamic>> createTask(
    Map<String, dynamic> task,
  ) async {
    final response = await _dio.post(
      ApiConfig.tasksEndpoint,
      data: task,
    );

    return Map<String, dynamic>.from(
      response.data,
    );
  }
}