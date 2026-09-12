import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import '../services/database_helper.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';
import '../core/network/dio_client.dart';
import '../config/api_config.dart';

class OfflineTasksScreen extends StatefulWidget {
  const OfflineTasksScreen({super.key});

  @override
  State<OfflineTasksScreen> createState() =>
      _OfflineTasksScreenState();
}

class _OfflineTasksScreenState
    extends State<OfflineTasksScreen> {
  List<Map<String, dynamic>> _tasks = [];

  bool _isOffline = false;
  bool _isSyncing = false;

  String? _lastSyncTime;

  final TextEditingController _taskController =
      TextEditingController();

  StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription;

  @override
  void initState() {
    super.initState();

    _checkConnectivityAndLoad();

    _connectivitySubscription =
        Connectivity()
            .onConnectivityChanged
            .listen(_onConnectivityChanged);
  }

  // ============================================================
  // DETECTAR CAMBIO DE CONECTIVIDAD
  // ============================================================

  Future<void> _onConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    final bool offline =
        results.contains(ConnectivityResult.none);

    if (!mounted) return;

    setState(() {
      _isOffline = offline;
    });

    if (!offline) {
      await _syncAndRefresh();
    } else {
      await _loadLocalTasks();
    }
  }

  // ============================================================
  // COMPROBAR CONECTIVIDAD AL ABRIR LA PANTALLA
  // ============================================================

  Future<void> _checkConnectivityAndLoad() async {
    final results =
        await Connectivity().checkConnectivity();

    final bool offline =
        results.contains(ConnectivityResult.none);

    if (!mounted) return;

    setState(() {
      _isOffline = offline;
    });

    if (offline) {
      await _loadLocalTasks();
    } else {
      await _syncAndRefresh();
    }
  }

  // ============================================================
  // SINCRONIZAR Y ACTUALIZAR
  // ============================================================

  Future<void> _syncAndRefresh() async {
    if (_isSyncing) return;

    _isSyncing = true;

    try {
      // Primero sincronizamos las tareas
      // que quedaron pendientes offline.
      await SyncService.processPendingQueue();

      // Después obtenemos las tareas del servidor.
      await _fetchRemoteTasks();

      // Finalmente cargamos las tareas locales.
      await _loadLocalTasks();
    } finally {
      _isSyncing = false;
    }
  }

  // ============================================================
  // OBTENER TAREAS DEL SERVIDOR
  // ============================================================

  Future<void> _fetchRemoteTasks() async {
    try {
      print('🌐 Consultando tareas al servidor...');

      final response =
          await DioClient.instance.dio.get(
        ApiConfig.tasksEndpoint,
      );

      print(
        '📥 Respuesta del servidor: '
        '${response.statusCode}',
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is List) {
          final List<Map<String, dynamic>> tasks =
              data
                  .whereType<Map>()
                  .map(
                    (item) =>
                        Map<String, dynamic>.from(item),
                  )
                  .toList();

          await DatabaseHelper.instance
              .saveTasksBatch(tasks);

          print(
            '✅ ${tasks.length} tareas guardadas localmente.',
          );
        }

        if (mounted) {
          setState(() {
            _isOffline = false;
            _lastSyncTime =
                _formatDateTime(DateTime.now());
          });
        }
      } else {
        print(
          '⚠️ El servidor respondió con código '
          '${response.statusCode}',
        );

        if (mounted) {
          setState(() {
            _isOffline = true;
          });
        }
      }
    } on DioException catch (e) {
      print(
        '❌ Error obteniendo tareas: '
        '${e.response?.statusCode} '
        '${e.response?.data ?? e.message}',
      );

      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }
    } catch (e) {
      print(
        '❌ Error inesperado obteniendo tareas: $e',
      );

      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }
    }
  }

  // ============================================================
  // CARGAR TAREAS DESDE SQLITE
  // ============================================================

  Future<void> _loadLocalTasks() async {
    final tasks =
        await DatabaseHelper.instance.getLocalTasks();

    if (!mounted) return;

    setState(() {
      _tasks = tasks;
    });

    if (tasks.isNotEmpty) {
      final validTask = tasks.firstWhere(
        (task) =>
            task['last_updated_server'] != null,
        orElse: () => <String, dynamic>{},
      );

      if (validTask.isNotEmpty) {
        _lastSyncTime =
            _formatDateTimeFromString(
          validTask['last_updated_server'],
        );
      }
    }
  }

  // ============================================================
  // CREAR TAREA OFFLINE
  // ============================================================

  Future<void> _addTaskOffline() async {
    final title =
        _taskController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Escribe una tarea primero.'),
        ),
      );
      return;
    }

    final String clientId =
        const Uuid().v4();

    final Map<String, dynamic> task = {
      'id': clientId,
      'client_id': clientId,
      'title': title,
      'description': '',
      'is_completed': 0,
      'is_synced': 0,
      'last_updated_server':
          DateTime.now().toIso8601String(),
    };

    try {
      // Guardar localmente y colocar
      // la operación en la cola.
      await DatabaseHelper.instance
          .insertLocalTaskOffline(task);

      _taskController.clear();

      await _loadLocalTasks();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tarea guardada localmente.',
          ),
        ),
      );

      // Comprobar si ya tenemos Internet.
      final results =
          await Connectivity().checkConnectivity();

      final bool offline =
          results.contains(
        ConnectivityResult.none,
      );

      if (!offline) {
        await _syncAndRefresh();
      }
    } catch (e) {
      print(
        '❌ Error guardando tarea offline: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Error: $e'),
        ),
      );
    }
  }

  // ============================================================
  // CERRAR SESIÓN
  // ============================================================

  Future<void> _logout() async {
    await SecureStorageService.clearAll();

    await DatabaseHelper.instance.clearDatabase();

    if (!mounted) return;

    setState(() {
      _tasks = [];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('Sesión cerrada correctamente.'),
      ),
    );
  }

  // ============================================================
  // FORMATO DE FECHA
  // ============================================================

  String _formatDateTime(DateTime dateTime) {
    final day =
        dateTime.day.toString().padLeft(2, '0');

    final month =
        dateTime.month.toString().padLeft(2, '0');

    final year =
        dateTime.year.toString();

    final hour =
        dateTime.hour.toString().padLeft(2, '0');

    final minute =
        dateTime.minute.toString().padLeft(2, '0');

    return '$day/$month/$year $hour:$minute';
  }

  String _formatDateTimeFromString(
    dynamic value,
  ) {
    try {
      final date =
          DateTime.parse(value.toString());

      return _formatDateTime(date);
    } catch (_) {
      return value.toString();
    }
  }

  // ============================================================
  // LIBERAR RECURSOS
  // ============================================================

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _taskController.dispose();

    super.dispose();
  }

  // ============================================================
  // INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Tareas Offline'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            icon:
                const Icon(Icons.sync),
            onPressed: _isSyncing
                ? null
                : _syncAndRefresh,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon:
                const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

      body: Column(
        children: [
          // ==================================================
          // INDICADOR DE CONEXIÓN
          // ==================================================

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(12),
            color: _isOffline
                ? Colors.orange.shade100
                : Colors.green.shade100,
            child: Row(
              children: [
                Icon(
                  _isOffline
                      ? Icons.cloud_off
                      : Icons.cloud_done,
                  color: _isOffline
                      ? Colors.orange
                      : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isOffline
                        ? 'Modo sin conexión'
                        : 'Conectado al servidor',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ==================================================
          // ÚLTIMA SINCRONIZACIÓN
          // ==================================================

          if (_lastSyncTime != null)
            Padding(
              padding:
                  const EdgeInsets.all(8),
              child: Text(
                'Última sincronización: '
                '$_lastSyncTime',
                style:
                    const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),

          // ==================================================
          // CAMPO PARA CREAR TAREA
          // ==================================================

          Padding(
            padding:
                const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller:
                        _taskController,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Nueva tarea',
                      hintText:
                          'Escribe una tarea',
                      border:
                          OutlineInputBorder(),
                    ),
                    onSubmitted: (_) =>
                        _addTaskOffline(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    size: 40,
                  ),
                  onPressed:
                      _addTaskOffline,
                ),
              ],
            ),
          ),

          // ==================================================
          // LISTA DE TAREAS
          // ==================================================

          Expanded(
            child: _tasks.isEmpty
                ? const Center(
                    child: Text(
                      'No hay tareas guardadas.',
                    ),
                  )
                : ListView.builder(
                    itemCount:
                        _tasks.length,
                    itemBuilder:
                        (context, index) {
                      final task =
                          _tasks[index];

                      final bool isSynced =
                          task['is_synced'] ==
                              1;

                      final String title =
                          task['title']
                                  ?.toString() ??
                              task['titulo']
                                  ?.toString() ??
                              'Tarea sin título';

                      final String description =
                          task['description']
                                  ?.toString() ??
                              task['descripcion']
                                  ?.toString() ??
                              '';

                      return Card(
                        margin:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: Icon(
                            isSynced
                                ? Icons
                                    .cloud_done
                                : Icons
                                    .cloud_upload,
                            color: isSynced
                                ? Colors.green
                                : Colors.orange,
                          ),
                          title:
                              Text(title),
                          subtitle:
                              Text(
                            description
                                    .isEmpty
                                ? 'Sin descripción'
                                : description,
                          ),
                          trailing:
                              isSynced
                                  ? const Text(
                                      'Sincronizada',
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.green,
                                        fontSize:
                                            11,
                                      ),
                                    )
                                  : const Text(
                                      'Pendiente',
                                      style:
                                          TextStyle(
                                        color:
                                            Colors.orange,
                                        fontSize:
                                            11,
                                      ),
                                    ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}