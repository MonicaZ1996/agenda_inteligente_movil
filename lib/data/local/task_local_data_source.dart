import '../../../services/database_helper.dart';

class TaskLocalDataSource {
  final DatabaseHelper _databaseHelper =
      DatabaseHelper.instance;

  Future<List<Map<String, dynamic>>> getTasks() async {
    return await _databaseHelper.getLocalTasks();
  }

  Future<void> saveTasks(
    List<Map<String, dynamic>> tasks,
  ) async {
    await _databaseHelper.saveTasksBatch(tasks);
  }

  Future<void> createTaskOffline(
    Map<String, dynamic> task,
  ) async {
    await _databaseHelper.insertLocalTaskOffline(
      task,
    );
  }

  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    return await _databaseHelper.getPendingQueue();
  }
}