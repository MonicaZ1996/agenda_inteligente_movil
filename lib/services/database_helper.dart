import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('agenda_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabla de tareas locales
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        is_completed INTEGER NOT NULL DEFAULT 0,
        last_updated_server TEXT,
        is_synced INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Tabla de cola de operaciones pendientes sin conexión
    await db.execute('''
      CREATE TABLE pending_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // Guardar batch de tareas del servidor
  Future<void> saveTasksBatch(List<Map<String, dynamic>> tasks) async {
    final db = await instance.database;
    final batch = db.batch();
    for (var task in tasks) {
      batch.insert(
        'tasks',
        {
          'id': task['id'].toString(),
          'client_id': task['client_id'] ?? task['id'].toString(),
          'title': task['titulo'] ?? task['nombre'] ?? '',
          'description': task['descripcion'] ?? '',
          'is_completed': (task['completada'] ?? false) == true ? 1 : 0,
          'last_updated_server': task['updated_at'] ?? DateTime.now().toIso8601String(),
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  // Obtener tareas guardadas localmente
  Future<List<Map<String, dynamic>>> getLocalTasks() async {
    final db = await instance.database;
    return await db.query('tasks', orderBy: 'is_synced ASC, title ASC');
  }

  // Insertar tarea en modo offline
  Future<void> insertLocalTaskOffline(Map<String, dynamic> taskData) async {
    final db = await instance.database;
    await db.insert('tasks', taskData);
    await db.insert('pending_queue', {
      'client_id': taskData['client_id'],
      'operation': 'CREATE',
      'payload': taskData['title'],
      'retry_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // Obtener cola de pendientes
  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final db = await instance.database;
    return await db.query('pending_queue', orderBy: 'id ASC');
  }

  Future<void> removeQueueItem(int id) async {
    final db = await instance.database;
    await db.delete('pending_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetryCount(int id, int currentCount) async {
    final db = await instance.database;
    await db.update('pending_queue', {'retry_count': currentCount + 1}, where: 'id = ?', whereArgs: [id]);
  }

  // Limpiar base de datos al cerrar sesión
  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.delete('tasks');
    await db.delete('pending_queue');
  }
}