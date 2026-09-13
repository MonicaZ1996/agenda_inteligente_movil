import 'dart:convert';
import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../core/network/dio_client.dart';
import 'database_helper.dart';

class SyncService {
  static const int maxRetries = 3;

  static Future<void> processPendingQueue() async {
    final queue = await DatabaseHelper.instance.getPendingQueue();

    for (final item in queue) {
      final queueId = item['id'] as int;
      final retries = (item['retry_count'] as int?) ?? 0;
      final clientId = item['client_id'].toString();
      final operation = item['operation'].toString();

      // Conservamos el registro para auditoría; no lo borramos al llegar al máximo.
      if (retries >= maxRetries) continue;
      if (operation != 'CREATE') continue;

      // Espera creciente: 1s, 2s, 4s.
      final waitSeconds = 1 << retries;
      if (retries > 0) {
        await Future<void>.delayed(Duration(seconds: waitSeconds));
      }

      try {
        final taskData = Map<String, dynamic>.from(
          jsonDecode(item['payload'].toString()) as Map,
        );

        final apiData = {
          'client_id': taskData['client_id']?.toString() ?? clientId,
          'titulo': taskData['titulo'] ?? taskData['title'] ?? '',
          'descripcion': taskData['descripcion'] ?? taskData['description'] ?? '',
          'completada': taskData['completada'] ?? (taskData['is_completed'] == 1),
        };

        final response = await DioClient.instance.dio.post(
          ApiConfig.tasksEndpoint,
          data: apiData,
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          final body = Map<String, dynamic>.from(response.data as Map);
          final serverTask = body['tarea'] is Map
              ? Map<String, dynamic>.from(body['tarea'] as Map)
              : body;

          await DatabaseHelper.instance.replaceTaskAfterSync(
            clientId: clientId,
            serverTask: serverTask,
          );
          await DatabaseHelper.instance.removeQueueItem(queueId);
        } else {
          await DatabaseHelper.instance.incrementRetryCount(
            queueId,
            retries,
            error: 'HTTP ${response.statusCode}',
          );
        }
      } on DioException catch (e) {
        await DatabaseHelper.instance.incrementRetryCount(
          queueId,
          retries,
          error: '${e.response?.statusCode ?? ''} ${e.message ?? ''}'.trim(),
        );
      } catch (e) {
        await DatabaseHelper.instance.incrementRetryCount(
          queueId,
          retries,
          error: e.toString(),
        );
      }
    }
  }
}
