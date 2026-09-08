import '../local/task_local_data_source.dart';
import '../remote/task_remote_data_source.dart';

class TaskRepository {
  final TaskRemoteDataSource remoteDataSource;
  final TaskLocalDataSource localDataSource;

  TaskRepository({
    TaskRemoteDataSource? remoteDataSource,
    TaskLocalDataSource? localDataSource,
  })  : remoteDataSource =
            remoteDataSource ?? TaskRemoteDataSource(),
        localDataSource =
            localDataSource ?? TaskLocalDataSource();

  Future<List<Map<String, dynamic>>> getTasks() async {
    try {
      final remoteTasks =
          await remoteDataSource.getTasks();

      await localDataSource.saveTasks(
        remoteTasks,
      );

      return remoteTasks;
    } catch (_) {
      return await localDataSource.getTasks();
    }
  }

  Future<void> createTaskOffline(
    Map<String, dynamic> task,
  ) async {
    await localDataSource.createTaskOffline(task);
  }
}