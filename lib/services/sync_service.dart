import 'dart:convert';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class SyncService {
  static const int maxRetries = 3;
  static const String baseUrl = 'http://localhost:5000/api/tareas';

  static Future<void> processPendingQueue() async {
    final queue = await DatabaseHelper.instance.getPendingQueue();
    if (queue.isEmpty) return;

    for (var item in queue) {
      final int queueId = item['id'];
      final int retries = item['retry_count'];

      if (retries >= maxRetries) {
        await DatabaseHelper.instance.removeQueueItem(queueId);
        continue;
      }

      try {
        final response = await http.post(
          Uri.parse(baseUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_id': item['client_id'],
            'titulo': item['payload'],
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          await DatabaseHelper.instance.removeQueueItem(queueId);
        } else {
          await DatabaseHelper.instance.incrementRetryCount(queueId, retries);
        }
      } catch (e) {
        await DatabaseHelper.instance.incrementRetryCount(queueId, retries);
      }
    }
  }
}