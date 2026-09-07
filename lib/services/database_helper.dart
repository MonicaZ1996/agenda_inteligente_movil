import 'dart:convert';
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
    // ============================================================
    // TABLA DE TAREAS LOCALES
    // ============================================================
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

    // ============================================================
    // COLA DE OPERACIONES PENDIENTES
    // ============================================================
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

  // ============================================================
  // GUARDAR TAREAS QUE VIENEN DEL SERVIDOR
  // ============================================================
  Future<void> saveTasksBatch(
    List<Map<String, dynamic>> tasks,
  ) async {
    final db = await instance.database;

    final batch = db.batch();

    for (final task in tasks) {
      batch.insert(
        'tasks',
        {
          'id': task['id'].toString(),

          'client_id':
              task['client_id']?.toString() ??
              task['id'].toString(),

          'title':
              task['titulo']?.toString() ??
              task['nombre']?.toString() ??
              task['title']?.toString() ??
              '',

          'description':
              task['descripcion']?.toString() ??
              task['description']?.toString() ??
              '',

          'is_completed':
              (task['completada'] ?? task['is_completed'] ?? false) == true
                  ? 1
                  : 0,

          'last_updated_server':
              task['updated_at']?.toString() ??
              DateTime.now().toIso8601String(),

          // Las tareas que vienen del servidor
          // ya están sincronizadas.
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  // ============================================================
  // OBTENER TAREAS LOCALES
  // ============================================================
  Future<List<Map<String, dynamic>>> getLocalTasks() async {
    final db = await instance.database;

    return await db.query(
      'tasks',
      orderBy: 'is_synced ASC, title ASC',
    );
  }

  // ============================================================
  // INSERTAR TAREA CREADA SIN INTERNET
  // ============================================================
  Future<void> insertLocalTaskOffline(
    Map<String, dynamic> taskData,
  ) async {
    final db = await instance.database;

    // Copiamos los datos para no modificar
    // directamente el mapa original.
    final localTask = Map<String, dynamic>.from(taskData);

    // Aseguramos que exista client_id.
    if (localTask['client_id'] == null) {
      localTask['client_id'] = localTask['id'].toString();
    }

    // La tarea todavía NO está sincronizada.
    localTask['is_synced'] = 0;

    // Valores por defecto.
    localTask['is_completed'] =
        localTask['is_completed'] ?? 0;

    localTask['description'] =
        localTask['description'] ?? '';

    localTask['last_updated_server'] =
        localTask['last_updated_server'] ??
        DateTime.now().toIso8601String();

    // ==========================================================
    // GUARDAR TAREA LOCAL
    // ==========================================================
    await db.insert(
      'tasks',
      localTask,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // ==========================================================
    // GUARDAR TODA LA INFORMACIÓN EN LA COLA
    // ==========================================================
    await db.insert(
      'pending_queue',
      {
        'client_id': localTask['client_id'].toString(),

        'operation': 'CREATE',

        // Guardamos el objeto completo como JSON.
        'payload': jsonEncode(localTask),

        'retry_count': 0,

        'created_at':
            DateTime.now().toIso8601String(),
      },
    );
  }

  // ============================================================
  // OBTENER COLA DE PENDIENTES
  // ============================================================
  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final db = await instance.database;

    return await db.query(
      'pending_queue',
      orderBy: 'id ASC',
    );
  }

  // ============================================================
  // MARCAR TAREA COMO SINCRONIZADA
  // ============================================================
  Future<void> markTaskAsSynced(
    String clientId,
  ) async {
    final db = await instance.database;

    await db.update(
      'tasks',
      {
        'is_synced': 1,
      },
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
  }

  // ============================================================
  // MARCAR TAREA COMO NO SINCRONIZADA
  // ============================================================
  Future<void> markTaskAsPending(
    String clientId,
  ) async {
    final db = await instance.database;

    await db.update(
      'tasks',
      {
        'is_synced': 0,
      },
      where: 'client_id = ?',
      whereArgs: [clientId],
    );
  }

  // ============================================================
  // ELIMINAR ELEMENTO DE LA COLA
  // ============================================================
  Future<void> removeQueueItem(int id) async {
    final db = await instance.database;

    await db.delete(
      'pending_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // AUMENTAR CONTADOR DE INTENTOS
  // ============================================================
  Future<void> incrementRetryCount(
    int id,
    int currentCount,
  ) async {
    final db = await instance.database;

    await db.update(
      'pending_queue',
      {
        'retry_count': currentCount + 1,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================================
  // LIMPIAR BASE DE DATOS AL CERRAR SESIÓN
  // ============================================================
  Future<void> clearDatabase() async {
    final db = await instance.database;

    await db.delete('tasks');
    await db.delete('pending_queue');
  }
}

