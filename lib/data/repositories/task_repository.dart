import '../../models/tarea.dart';
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

  // ==============================
  // OBTENER TAREAS
  // ==============================
  Future<List<Tarea>> getTasks() async {
    try {
      final remoteTasks =
          await remoteDataSource.getTasks();

      final tasksAsMaps =
          remoteTasks.map((t) => t.toJson()).toList();

      await localDataSource.saveTasks(tasksAsMaps);

      return remoteTasks;
    } catch (_) {
      final localMaps =
          await localDataSource.getTasks();

      return localMaps
          .map((map) => Tarea.fromJson(map))
          .toList();
    }
  }

  // ==============================
  // CREAR TAREA EN EL BACKEND
  // ==============================
  Future<Tarea> createTask(
    Map<String, dynamic> task,
  ) async {
    final createdTask =
        await remoteDataSource.createTask(task);

    // Guardamos también la tarea creada
    // en la base de datos local.
    await localDataSource.saveTasks([
      createdTask.toJson(),
    ]);

    return createdTask;
  }

  // ==============================
  // CREAR TAREA SIN INTERNET
  // ==============================
  Future<void> createTaskOffline(
    Map<String, dynamic> task,
  ) async {
    await localDataSource.createTaskOffline(task);
  }
}