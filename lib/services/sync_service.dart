import 'dart:convert';
import 'package:dio/dio.dart';
import 'database_helper.dart';
import '../core/network/dio_client.dart';
import '../config/api_config.dart';

class SyncService {
  static const int maxRetries = 3;

  // ============================================================
  // PROCESAR COLA DE TAREAS PENDIENTES
  // ============================================================
  static Future<void> processPendingQueue() async {
    final queue =
        await DatabaseHelper.instance.getPendingQueue();

    // No hay tareas pendientes.
    if (queue.isEmpty) {
      return;
    }

    for (final item in queue) {
      final int queueId = item['id'] as int;

      final int retries =
          (item['retry_count'] as int?) ?? 0;

      final String clientId =
          item['client_id'].toString();

      // ========================================================
      // SI YA SUPERÓ EL MÁXIMO DE INTENTOS
      // ========================================================
      if (retries >= maxRetries) {
        await DatabaseHelper.instance.removeQueueItem(
          queueId,
        );

        continue;
      }

      try {
        // ======================================================
        // RECUPERAR PAYLOAD GUARDADO COMO JSON
        // ======================================================
        Map<String, dynamic> taskData;

        try {
          taskData = jsonDecode(
            item['payload'].toString(),
          ) as Map<String, dynamic>;
        } catch (_) {
          // Compatibilidad con tareas antiguas.
          taskData = {
            'client_id': clientId,
            'titulo': item['payload'].toString(),
          };
        }

        // Asegurar client_id.
        taskData['client_id'] =
            taskData['client_id'] ?? clientId;

        // ======================================================
        // PREPARAR DATOS PARA LA API
        // ======================================================
        final Map<String, dynamic> apiData = {
          'client_id':
              taskData['client_id'].toString(),

          'titulo':
              taskData['titulo'] ??
              taskData['title'] ??
              '',

          'descripcion':
              taskData['descripcion'] ??
              taskData['description'] ??
              '',

          'completada':
              taskData['completada'] ??
              (taskData['is_completed'] == 1),
        };

        // ======================================================
        // ENVIAR TAREA USANDO DIO
        // ======================================================
        final response =
            await DioClient.instance.dio.post(
          ApiConfig.tasksEndpoint,
          data: apiData,
        );

        // ======================================================
        // SINCRONIZACIÓN EXITOSA
        // ======================================================
        if (response.statusCode == 200 ||
            response.statusCode == 201) {

          // Mostrar en consola la respuesta del servidor.
          print(
            '✅ TAREA SINCRONIZADA: ${response.data}',
          );

          // Marcar la tarea local como sincronizada.
          await DatabaseHelper.instance.markTaskAsSynced(
            clientId,
          );

          // Eliminar de la cola.
          await DatabaseHelper.instance.removeQueueItem(
            queueId,
          );
        } else {
          await DatabaseHelper.instance.incrementRetryCount(
            queueId,
            retries,
          );
        }
      }

      // ========================================================
      // ERROR DE DIO / CONEXIÓN / SERVIDOR
      // ========================================================
      on DioException catch (e) {
        print(
          '❌ Error sincronizando tarea: '
          '${e.response?.statusCode} '
          '${e.response?.data ?? e.message}',
        );

        await DatabaseHelper.instance.incrementRetryCount(
          queueId,
          retries,
        );
      }

      // ========================================================
      // OTROS ERRORES
      // ========================================================
      catch (e) {
        print(
          '❌ Error inesperado sincronizando tarea: $e',
        );

        await DatabaseHelper.instance.incrementRetryCount(
          queueId,
          retries,
        );
      }
    }
  }
}

