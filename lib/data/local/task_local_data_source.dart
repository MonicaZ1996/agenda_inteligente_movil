import '../../models/tarea.dart';
import '../../services/database_helper.dart';

class TaskLocalDataSource {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  Future<List<Tarea>> getTasks() async {
    final rows = await _databaseHelper.getLocalTasks();

    return rows.map((row) {
      return Tarea.fromJson({
        'id': row['id'].toString(),
        'client_id': row['client_id']?.toString(),
        'titulo': row['title']?.toString() ?? '',
        'descripcion': row['description']?.toString(),
        'completada': row['is_completed'] == 1,
        'updated_at': row['last_updated_server']?.toString(),
        'is_synced': row['is_synced'] == 1,
      });
    }).toList();
  }

  Future<void> saveTasks(List<Tarea> tasks) async {
    await _databaseHelper.saveTasksBatch(
      tasks.map((task) => task.toJson()).toList(),
    );
  }

  Future<void> createTaskOffline(Map<String, dynamic> task) async {
    await _databaseHelper.insertLocalTaskOffline(task);
  }

  Future<void> clearAll() => _databaseHelper.clearDatabase();
}
