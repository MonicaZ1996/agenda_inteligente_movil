import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
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

  String _lastSyncTime = 'Sin datos';

  final TextEditingController _taskController =
      TextEditingController();

  StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription;

  bool _isSyncing = false;

  @override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PRUEBA: OfflineTasksScreen está funcionando'),
        duration: Duration(seconds: 5),
      ),
    );
  });

  _checkConnectivityAndLoad();

  _connectivitySubscription =
      Connectivity().onConnectivityChanged.listen(
    (List<ConnectivityResult> results) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CONECTIVIDAD DETECTADA: $results'),
          duration: const Duration(seconds: 3),
        ),
      );

      _onConnectivityChanged(results);
    },
  );
}
  // ============================================================
  // DETECTAR CAMBIO DE CONECTIVIDAD
  // ============================================================
  Future<void> _onConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    debugPrint('🔵 CAMBIO DE CONECTIVIDAD DETECTADO: $results');
    final bool networkDisconnected =
        results.contains(ConnectivityResult.none);

    if (networkDisconnected) {
      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }

      await _loadLocalTasks();

      return;
    }

    // ==========================================================
    // VOLVIÓ LA CONEXIÓN
    // ==========================================================

    if (mounted) {
      setState(() {
        _isOffline = false;
      });
    }

    await _syncAndRefresh();
  }

  // ============================================================
  // COMPROBAR CONECTIVIDAD AL ABRIR LA PANTALLA
  // ============================================================
  Future<void> _checkConnectivityAndLoad() async {
    final connectivityResult =
        await Connectivity().checkConnectivity();

    final bool networkDisconnected =
        connectivityResult.contains(ConnectivityResult.none);

    if (networkDisconnected) {
      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }

      await _loadLocalTasks();
      return;
    }

    // Hay una conexión de red.
    if (mounted) {
      setState(() {
        _isOffline = false;
      });
    }

    await _syncAndRefresh();
  }

  // ============================================================
  // SINCRONIZAR PENDIENTES Y ACTUALIZAR DATOS
  // ============================================================
  Future<void> _syncAndRefresh() async {
    // Evitar dos sincronizaciones simultáneas.
    if (_isSyncing) {
      return;
    }

    _isSyncing = true;

    try {
      // --------------------------------------------------------
      // PASO 1: PROCESAR TAREAS PENDIENTES
      // --------------------------------------------------------
      await SyncService.processPendingQueue();

      // --------------------------------------------------------
      // PASO 2: COMPROBAR QUE EL SERVIDOR ESTÁ DISPONIBLE
      // --------------------------------------------------------
      await _fetchRemoteTasks();

      // --------------------------------------------------------
      // PASO 3: CARGAR LAS TAREAS LOCALES ACTUALIZADAS
      // --------------------------------------------------------
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
      final response = await http
          .get(
            Uri.parse(
              'http://192.168.100.34:5000/api/tareas',
            ),
          )
          .timeout(
            const Duration(seconds: 4),
          );

      if (response.statusCode == 200) {
        final List<dynamic> data =
            jsonDecode(response.body);

        await DatabaseHelper.instance.saveTasksBatch(
          data.cast<Map<String, dynamic>>(),
        );

        if (mounted) {
          setState(() {
            _isOffline = false;
            _lastSyncTime = _formatDateTime(
              DateTime.now(),
            );
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isOffline = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOffline = true;
        });
      }
    }
  }

  // ============================================================
  // CARGAR TAREAS LOCALES
  // ============================================================
  Future<void> _loadLocalTasks() async {
    final localData =
        await DatabaseHelper.instance.getLocalTasks();

    if (!mounted) {
      return;
    }

    setState(() {
      _tasks = localData;

      // Buscar una fecha válida para mostrar.
      for (final task in localData) {
        final serverDate =
            task['last_updated_server'];

        if (serverDate != null &&
            serverDate.toString().isNotEmpty) {
          _lastSyncTime =
              _formatDateTimeFromString(
            serverDate.toString(),
          );

          break;
        }
      }
    });
  }

  // ============================================================
  // CREAR NUEVA TAREA
  // ============================================================
  Future<void> _addTaskOffline() async {
    final title = _taskController.text.trim();

    if (title.isEmpty) {
      return;
    }

    final clientId = const Uuid().v4();

    final newTask = {
      'id': clientId,
      'client_id': clientId,
      'title': title,
      'description': 'Creada sin conexión',
      'is_completed': 0,
      'last_updated_server':
          DateTime.now().toIso8601String(),
      'is_synced': 0,
    };

    // Guardar localmente como pendiente.
    await DatabaseHelper.instance.insertLocalTaskOffline(
      newTask,
    );

    _taskController.clear();

    // Mostrar inmediatamente la nube naranja.
    await _loadLocalTasks();

    // Si tenemos conexión, intentar sincronizar.
    final connectivityResult =
        await Connectivity().checkConnectivity();

    final bool networkDisconnected =
        connectivityResult.contains(ConnectivityResult.none);

    if (!networkDisconnected) {
      await _syncAndRefresh();
    }
  }

  // ============================================================
  // CERRAR SESIÓN
  // ============================================================
  Future<void> _logout() async {
    await SecureStorageService.clearAll();

    await DatabaseHelper.instance.clearDatabase();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sesión cerrada y almacén local eliminado.',
          ),
        ),
      );

      setState(() {
        _tasks = [];
        _lastSyncTime = 'Limpiado';
      });
    }
  }

  // ============================================================
  // FORMATEAR FECHA
  // ============================================================
  String _formatDateTime(DateTime dateTime) {
    final String year = dateTime.year.toString();

    final String month =
        dateTime.month.toString().padLeft(2, '0');

    final String day =
        dateTime.day.toString().padLeft(2, '0');

    final String hour =
        dateTime.hour.toString().padLeft(2, '0');

    final String minute =
        dateTime.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }

  String _formatDateTimeFromString(String value) {
    try {
      final dateTime = DateTime.parse(value);

      return _formatDateTime(dateTime);
    } catch (e) {
      return value.length >= 16
          ? value.substring(0, 16)
          : value;
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
        title: const Text(
          'Agenda Offline-First',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _checkConnectivityAndLoad,

        child: Column(
          children: [
            // ==================================================
            // BANNER DE ESTADO DE RED
            // ==================================================
            Container(
              color: _isOffline
                  ? Colors.orange.shade100
                  : Colors.green.shade100,

              padding: const EdgeInsets.all(12),

              child: Row(
                children: [
                  Icon(
                    _isOffline
                        ? Icons.wifi_off
                        : Icons.wifi,

                    color: _isOffline
                        ? Colors.deepOrange
                        : Colors.green,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      _isOffline
                          ? 'Modo sin conexión | Datos de: $_lastSyncTime'
                          : 'En línea | Sincronizado: $_lastSyncTime',

                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // FORMULARIO DE CREACIÓN
            // ==================================================
            Padding(
              padding: const EdgeInsets.all(12.0),

              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _taskController,

                      decoration:
                          const InputDecoration(
                        labelText:
                            'Nueva tarea offline',

                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  ElevatedButton(
                    onPressed: _addTaskOffline,

                    child: const Text(
                      'Guardar',
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // LISTA DE TAREAS
            // ==================================================
            Expanded(
              child: ListView.builder(
                itemCount: _tasks.length,

                itemBuilder: (
                  context,
                  index,
                ) {
                  final item = _tasks[index];

                  final bool isSynced =
                      item['is_synced'] == 1;

                  return ListTile(
                    title: Text(
                      item['title'] ?? '',
                    ),

                    subtitle: Text(
                      item['description'] ?? '',
                    ),

                    trailing: Icon(
                      isSynced
                          ? Icons.cloud_done
                          : Icons.cloud_upload,

                      color: isSynced
                          ? Colors.green
                          : Colors.orange,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

