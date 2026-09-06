import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/database_helper.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';

class OfflineTasksScreen extends StatefulWidget {
  const OfflineTasksScreen({super.key});

  @override
  State<OfflineTasksScreen> createState() => _OfflineTasksScreenState();
}

class _OfflineTasksScreenState extends State<OfflineTasksScreen> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isOffline = false;
  String _lastSyncTime = 'Sin datos';
  final TextEditingController _taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkConnectivityAndLoad();
  }

  Future<void> _checkConnectivityAndLoad() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _isOffline = connectivityResult.contains(ConnectivityResult.none);

    if (!_isOffline) {
      await _fetchRemoteTasks();
      await SyncService.processPendingQueue();
    }
    await _loadLocalTasks();
  }

  Future<void> _fetchRemoteTasks() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:5000/api/tareas'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        await DatabaseHelper.instance
            .saveTasksBatch(data.cast<Map<String, dynamic>>());
      }
    } catch (_) {
      _isOffline = true;
    }
  }

  Future<void> _loadLocalTasks() async {
    final localData = await DatabaseHelper.instance.getLocalTasks();
    setState(() {
      _tasks = localData;
      if (localData.isNotEmpty &&
          localData.first['last_updated_server'] != null) {
        _lastSyncTime =
            localData.first['last_updated_server'].toString().substring(0, 16);
      }
    });
  }

  Future<void> _addTaskOffline() async {
    if (_taskController.text.trim().isEmpty) return;

    final clientId = const Uuid().v4();
    final newTask = {
      'id': clientId,
      'client_id': clientId,
      'title': _taskController.text.trim(),
      'description': 'Creada sin conexión',
      'is_completed': 0,
      'last_updated_server': DateTime.now().toIso8601String(),
      'is_synced': 0,
    };

    await DatabaseHelper.instance.insertLocalTaskOffline(newTask);
    _taskController.clear();
    await _loadLocalTasks();
  }

  Future<void> _logout() async {
    await SecureStorageService.clearAll();
    await DatabaseHelper.instance.clearDatabase();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sesión cerrada y almacén local eliminado.')),
      );
      setState(() {
        _tasks = [];
        _lastSyncTime = 'Limpiado';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda Offline-First'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          )
        ],
      ),
      body: Column(
        children: [
          // Banner de estado de red y antigüedad de datos
          Container(
            color: _isOffline ? Colors.orange.shade100 : Colors.green.shade100,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  _isOffline ? Icons.wifi_off : Icons.wifi,
                  color: _isOffline ? Colors.deepOrange : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isOffline
                        ? 'Modo sin conexión | Datos de: $_lastSyncTime'
                        : 'En línea | Sincronizado: $_lastSyncTime',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          // Formulario de creación de tarea
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'Nueva tarea offline',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addTaskOffline,
                  child: const Text('Guardar'),
                )
              ],
            ),
          ),
          // Lista de tareas locales
          Expanded(
            child: ListView.builder(
              itemCount: _tasks.length,
              itemBuilder: (context, index) {
                final item = _tasks[index];
                final isSynced = item['is_synced'] == 1;

                return ListTile(
                  title: Text(item['title']),
                  subtitle: Text(item['description'] ?? ''),
                  trailing: Icon(
                    isSynced ? Icons.cloud_done : Icons.cloud_upload,
                    color: isSynced ? Colors.green : Colors.orange,
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}