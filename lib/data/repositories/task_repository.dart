import 'package:dio/dio.dart';

import '../../core/network/network_error_mapper.dart';
import '../../models/tarea.dart';
import '../../services/sync_service.dart';
import '../local/task_local_data_source.dart';
import '../remote/task_remote_data_source.dart';

class TaskRepository {
  final TaskRemoteDataSource remoteDataSource;
  final TaskLocalDataSource localDataSource;

  TaskRepository({
    TaskRemoteDataSource? remoteDataSource,
    TaskLocalDataSource? localDataSource,
  })  : remoteDataSource = remoteDataSource ?? TaskRemoteDataSource(),
        localDataSource = localDataSource ?? TaskLocalDataSource();

  Future<List<Tarea>> getRemoteThenCache() async {
    try {
      final remoteTasks = await remoteDataSource.getTasks();
      await localDataSource.saveTasks(remoteTasks);
      return remoteTasks;
    } on DioException catch (e) {
      final local = await localDataSource.getTasks();
      if (local.isNotEmpty) return local;
      throw Exception(NetworkErrorMapper.toDomainMessage(e));
    }
  }

  Future<List<Tarea>> getLocalTasks() => localDataSource.getTasks();

  Future<void> createTaskOffline(Map<String, dynamic> task) =>
      localDataSource.createTaskOffline(task);

  Future<List<Tarea>> synchronize() async {
    await SyncService.processPendingQueue();
    return getRemoteThenCache();
  }

  Future<void> clearLocalData() => localDataSource.clearAll();
}
