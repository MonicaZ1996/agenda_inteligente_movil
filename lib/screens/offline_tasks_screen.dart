import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import '../core/network/dio_client.dart';
import '../services/database_helper.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';

class OfflineTasksScreen extends StatefulWidget {
  const OfflineTasksScreen({super.key});

  @override
  State<OfflineTasksScreen> createState() =>
      _OfflineTasksScreenState();
}

class _OfflineTasksScreenState extends State<OfflineTasksScreen> {
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

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  Future<void> _onConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    final offline =
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

  Future<void> _checkConnectivityAndLoad() async {
    final results =
        await Connectivity().checkConnectivity();

    final offline =
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

  Future<void> _syncAndRefresh() async {
    if (_isSyncing) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      await SyncService.processPendingQueue();
      await _fetchRemoteTasks();
      await _loadLocalTasks();
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _fetchRemoteTasks() async {
    try {
      debugPrint(
        'Consultando tareas al servidor...',
      );

      final response =
          await DioClient.instance.dio.get(
        ApiConfig.tasksEndpoint,
      );

      if (response.statusCode == 200) {
        final data = response.data;

        if (data is List) {
          final tasks = data
              .whereType<Map>()
              .map(
                (item) =>
                    Map<String, dynamic>.from(item),
              )
              .toList();

          await DatabaseHelper.instance
              .saveTasksBatch(tasks);
        }

        if (!mounted) return;

        setState(() {
          _isOffline = false;
          _lastSyncTime =
              _formatDateTime(DateTime.now());
        });
      }
    } on DioException catch (e) {
      debugPrint(
        'Error obteniendo tareas: ${e.message}',
      );

      if (!mounted) return;

      setState(() {
        _isOffline = true;
      });
    } catch (e) {
      debugPrint(
        'Error inesperado obteniendo tareas: $e',
      );

      if (!mounted) return;

      setState(() {
        _isOffline = true;
      });
    }
  }

  Future<void> _loadLocalTasks() async {
    final tasks =
        await DatabaseHelper.instance.getLocalTasks();

    if (!mounted) return;

    setState(() {
      _tasks = tasks;
    });

    if (tasks.isNotEmpty) {
      final task = tasks.firstWhere(
        (item) =>
            item['last_updated_server'] != null,
        orElse: () => <String, dynamic>{},
      );

      if (task.isNotEmpty) {
        setState(() {
          _lastSyncTime =
              _formatDateTimeFromString(
            task['last_updated_server'],
          );
        });
      }
    }
  }

  Future<void> _addTaskOffline() async {
    final title =
        _taskController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Escribe una tarea primero.',
          ),
        ),
      );

      return;
    }

    final clientId =
        const Uuid().v4();

    final task = <String, dynamic>{
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
      await DatabaseHelper.instance
          .insertLocalTaskOffline(task);

      _taskController.clear();

      await _loadLocalTasks();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tarea guardada correctamente.',
          ),
        ),
      );

      final results =
          await Connectivity().checkConnectivity();

      final offline =
          results.contains(ConnectivityResult.none);

      if (!offline) {
        await _syncAndRefresh();
      }
    } catch (e) {
      debugPrint(
        'Error guardando tarea: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al guardar: $e',
          ),
        ),
      );
    }
  }

  Future<void> _logout() async {
    await SecureStorageService.clearAll();
    await DatabaseHelper.instance.clearDatabase();

    if (!mounted) return;

    setState(() {
      _tasks.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Sesión cerrada correctamente.',
        ),
      ),
    );
  }

  String _formatDateTime(
    DateTime dateTime,
  ) {
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

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _taskController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agenda de Tareas',
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            onPressed:
                _isSyncing ? null : _syncAndRefresh,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon:
                const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
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

          if (_lastSyncTime != null)
            Padding(
              padding:
                  const EdgeInsets.all(8),
              child: Text(
                _isOffline
                    ? 'Datos locales - Última sincronización: $_lastSyncTime'
                    : 'Última sincronización: $_lastSyncTime',
                style:
                    const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),

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
                    onSubmitted: (_) {
                      _addTaskOffline();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Agregar tarea',
                  onPressed:
                      _addTaskOffline,
                  icon: const Icon(
                    Icons.add_circle,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),

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

                      final title =
                          task['title']
                                  ?.toString() ??
                              task['titulo']
                                  ?.toString() ??
                              'Tarea sin título';

                      final description =
                          task['description']
                                  ?.toString() ??
                              task['descripcion']
                                  ?.toString() ??
                              '';

                      final isSynced =
                          task['is_synced'] == 1;

                      final isCompleted =
                          task['is_completed'] ==
                                  1 ||
                              task['estado']
                                      ?.toString()
                                      .toLowerCase() ==
                                  'completada';

                      return Card(
                        margin:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: ListTile(
                          leading: Icon(
                            isCompleted
                                ? Icons
                                    .check_circle
                                : Icons
                                    .radio_button_unchecked,
                            color: isCompleted
                                ? Colors.green
                                : Colors.grey,
                          ),
                          title: Text(
                            title,
                            style:
                                TextStyle(
                              decoration:
                                  isCompleted
                                      ? TextDecoration
                                          .lineThrough
                                      : null,
                            ),
                          ),
                          subtitle:
                              Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              Text(
                                description.isEmpty
                                    ? 'Sin descripción'
                                    : description,
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                isSynced
                                    ? 'Sincronizada'
                                    : 'Pendiente de envío',
                                style:
                                    TextStyle(
                                  fontSize: 11,
                                  color: isSynced
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                              ),
                            ],
                          ),
                          trailing: Icon(
                            isSynced
                                ? Icons.cloud_done
                                : Icons.cloud_upload,
                            color: isSynced
                                ? Colors.green
                                : Colors.orange,
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