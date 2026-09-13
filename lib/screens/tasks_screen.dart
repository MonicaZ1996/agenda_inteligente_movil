import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../data/repositories/auth_repository.dart';
import '../data/repositories/task_repository.dart';
import '../models/tarea.dart';
import 'login_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final TaskRepository _repository = TaskRepository();
  final AuthRepository _authRepository = AuthRepository();
  final TextEditingController _taskController = TextEditingController();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  List<Tarea> _tasks = [];
  bool _loading = true;
  bool _isOffline = false;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _lastServerUpdate;

  @override
  void initState() {
    super.initState();
    _initialize();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  Future<void> _initialize() async {
    final results = await Connectivity().checkConnectivity();
    final offline = results.contains(ConnectivityResult.none);

    if (!mounted) return;
    setState(() => _isOffline = offline);

    if (offline) {
      await _loadLocal();
    } else {
      await _syncAndLoad();
    }
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final offline = results.contains(ConnectivityResult.none);
    if (!mounted) return;

    setState(() => _isOffline = offline);

    if (offline) {
      await _loadLocal();
    } else {
      await _syncAndLoad();
    }
  }

  Future<void> _loadLocal() async {
    try {
      final tasks = await _repository.getLocalTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _loading = false;
        _errorMessage = null;
        _lastServerUpdate = _latestServerTimestamp(tasks);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'No se pudieron leer los datos locales.';
      });
    }
  }

  Future<void> _syncAndLoad() async {
    if (_isSyncing) return;

    if (mounted) {
      setState(() {
        _isSyncing = true;
        _loading = _tasks.isEmpty;
        _errorMessage = null;
      });
    }

    try {
      final tasks = await _repository.synchronize();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isOffline = false;
        _lastServerUpdate = _latestServerTimestamp(tasks);
      });
    } catch (e) {
      final local = await _repository.getLocalTasks();
      if (!mounted) return;
      setState(() {
        _tasks = local;
        _isOffline = true;
        _errorMessage = local.isEmpty
            ? e.toString().replaceFirst('Exception: ', '')
            : null;
        _lastServerUpdate = _latestServerTimestamp(local);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _addTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty) {
      _showMessage('Escribe una tarea primero.');
      return;
    }

    final clientId = const Uuid().v4();
    final task = <String, dynamic>{
      'id': clientId,
      'client_id': clientId,
      'title': title,
      'description': '',
      'is_completed': 0,
      'last_updated_server': null,
      'is_synced': 0,
    };

    await _repository.createTaskOffline(task);
    _taskController.clear();
    await _loadLocal();

    if (!mounted) return;
    _showMessage(
      _isOffline
          ? 'Tarea guardada sin conexión. Se enviará al recuperar Internet.'
          : 'Tarea guardada. Sincronizando con el servidor...',
    );

    if (!_isOffline) await _syncAndLoad();
  }

  String? _latestServerTimestamp(List<Tarea> tasks) {
    final dates = tasks
        .where((t) => t.updatedAt != null && t.updatedAt!.isNotEmpty)
        .map((t) => DateTime.tryParse(t.updatedAt!))
        .whereType<DateTime>()
        .toList();

    if (dates.isEmpty) return null;
    dates.sort();
    return _formatDate(dates.last.toLocal());
  }

  String _formatDate(DateTime date) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  Future<void> _logout() async {
    await _authRepository.logout();
    await _repository.clearLocalData();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
        title: const Text('Agenda de Tareas'),
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            onPressed: _isSyncing ? null : _syncAndLoad,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: _isOffline ? Colors.orange.shade100 : Colors.green.shade100,
            child: Row(
              children: [
                Icon(
                  _isOffline ? Icons.cloud_off : Icons.cloud_done,
                  color: _isOffline ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isOffline
                        ? 'Modo sin conexión · mostrando datos locales'
                        : 'Conectado al servidor',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          if (_lastServerUpdate != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _isOffline
                      ? 'Datos del servidor actualizados por última vez: $_lastServerUpdate'
                      : 'Última actualización del servidor: $_lastServerUpdate',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    decoration: const InputDecoration(
                      labelText: 'Nueva tarea',
                      hintText: 'Escribe una tarea',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Agregar tarea',
                  onPressed: _addTask,
                  icon: const Icon(Icons.add_circle, size: 40),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? const Center(child: Text('No hay tareas guardadas.'))
                    : RefreshIndicator(
                        onRefresh: _isOffline ? _loadLocal : _syncAndLoad,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  task.isSynced
                                      ? Icons.cloud_done
                                      : Icons.cloud_upload,
                                  color: task.isSynced
                                      ? Colors.green
                                      : Colors.orange,
                                ),
                                title: Text(task.titulo),
                                subtitle: Text(
                                  '${task.completada ? 'Completada' : 'Pendiente'} · '
                                  '${task.isSynced ? 'Sincronizada' : 'Pendiente de envío'}',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
