import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class SyncService {
  static const int maxRetries = 3;

  static const String baseUrl =
      'http://192.168.100.34:5000/api/tareas';

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
        } catch (e) {
          // Si por alguna razón existe una tarea antigua
          // cuyo payload solamente contiene el título,
          // usamos ese valor como título.
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
  'client_id': taskData['client_id'].toString(),

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
        // ENVIAR TAREA AL SERVIDOR
        // ======================================================
        final response = await http.post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(apiData),
        );

        // ======================================================
        // SINCRONIZACIÓN EXITOSA
        // ======================================================
        if (response.statusCode == 200 ||
            response.statusCode == 201) {
          // PRIMERO marcar la tarea local como sincronizada.
          await DatabaseHelper.instance.markTaskAsSynced(
            clientId,
          );

          // DESPUÉS eliminarla de la cola.
          await DatabaseHelper.instance.removeQueueItem(
            queueId,
          );
        }

        // ======================================================
        // ERROR DEL SERVIDOR
        // ======================================================
        else {
          await DatabaseHelper.instance.incrementRetryCount(
            queueId,
            retries,
          );
        }
      }

      // ========================================================
      // ERROR DE CONEXIÓN
      // ========================================================
      catch (e) {
        await DatabaseHelper.instance.incrementRetryCount(
          queueId,
          retries,
        );
      }
    }
  }
}

