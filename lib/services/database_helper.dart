import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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

    return openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
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

    await db.execute('''
      CREATE TABLE pending_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_error TEXT
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE pending_queue ADD COLUMN last_error TEXT');
    }
  }

  Future<void> saveTasksBatch(List<Map<String, dynamic>> tasks) async {
    final db = await instance.database;
    final batch = db.batch();

    for (final task in tasks) {
      final id = task['id'].toString();
      final clientId = task['client_id']?.toString() ?? id;

      batch.insert(
        'tasks',
        {
          'id': id,
          'client_id': clientId,
          'title': task['titulo']?.toString() ??
              task['nombre']?.toString() ??
              task['title']?.toString() ??
              '',
          'description': task['descripcion']?.toString() ??
              task['description']?.toString() ??
              '',
          'is_completed': _asCompletedInt(
            task['completada'] ?? task['is_completed'] ?? false,
          ),
          // Esta marca proviene del servidor. No se inventa con la hora local.
          'last_updated_server': task['updated_at']?.toString(),
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  int _asCompletedInt(dynamic value) {
    if (value == true || value == 1 || value?.toString() == '1') return 1;
    return 0;
  }

  Future<List<Map<String, dynamic>>> getLocalTasks() async {
    final db = await instance.database;
    return db.query(
      'tasks',
      orderBy: 'is_synced ASC, title ASC',
    );
  }

  Future<void> insertLocalTaskOffline(Map<String, dynamic> taskData) async {
    final db = await instance.database;
    final localTask = Map<String, dynamic>.from(taskData);

    localTask['client_id'] ??= localTask['id'].toString();
    localTask['is_synced'] = 0;
    localTask['is_completed'] ??= 0;
    localTask['description'] ??= '';
    localTask['last_updated_server'] = null;

    await db.transaction((txn) async {
      await txn.insert(
        'tasks',
        localTask,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.insert(
        'pending_queue',
        {
          'client_id': localTask['client_id'].toString(),
          'operation': 'CREATE',
          'payload': jsonEncode(localTask),
          'retry_count': 0,
          'created_at': DateTime.now().toIso8601String(),
          'last_error': null,
        },
      );
    });
  }

  Future<List<Map<String, dynamic>>> getPendingQueue() async {
    final db = await instance.database;
    return db.query('pending_queue', orderBy: 'id ASC');
  }

  Future<void> replaceTaskAfterSync({
    required String clientId,
    required Map<String, dynamic> serverTask,
  }) async {
    final db = await instance.database;

    await db.transaction((txn) async {
      await txn.delete(
        'tasks',
        where: 'client_id = ?',
        whereArgs: [clientId],
      );

      await txn.insert(
        'tasks',
        {
          'id': serverTask['id'].toString(),
          'client_id': serverTask['client_id']?.toString() ?? clientId,
          'title': serverTask['titulo']?.toString() ?? '',
          'description': serverTask['descripcion']?.toString() ?? '',
          'is_completed': _asCompletedInt(serverTask['completada']),
          'last_updated_server': serverTask['updated_at']?.toString(),
          'is_synced': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> removeQueueItem(int id) async {
    final db = await instance.database;
    await db.delete('pending_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> incrementRetryCount(
    int id,
    int currentCount, {
    String? error,
  }) async {
    final db = await instance.database;
    await db.update(
      'pending_queue',
      {
        'retry_count': currentCount + 1,
        'last_error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearDatabase() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.delete('tasks');
      await txn.delete('pending_queue');
    });
  }
}
