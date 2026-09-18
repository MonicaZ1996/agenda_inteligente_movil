import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
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
  final ImagePicker _imagePicker = ImagePicker();

  StreamSubscription<List<ConnectivityResult>>?
      _connectivitySubscription;

  List<Tarea> _tasks = [];

  bool _loading = true;
  bool _isOffline = false;
  bool _isSyncing = false;
  bool _gettingLocation = false;
  bool _takingPhoto = false;

  String? _errorMessage;
  String? _lastServerUpdate;

  Position? _currentPosition;
  XFile? _taskPhoto;

  @override
  void initState() {
    super.initState();

    _initialize();

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen(_onConnectivityChanged);
  }

  // ============================================================
  // CONECTIVIDAD Y CARGA DE DATOS
  // ============================================================

  Future<void> _initialize() async {
    final results = await Connectivity().checkConnectivity();

    final offline = results.contains(
      ConnectivityResult.none,
    );

    if (!mounted) return;

    setState(() {
      _isOffline = offline;
    });

    if (offline) {
      await _loadLocal();
    } else {
      await _syncAndLoad();
    }
  }

  Future<void> _onConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    final offline = results.contains(
      ConnectivityResult.none,
    );

    if (!mounted) return;

    setState(() {
      _isOffline = offline;
    });

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
        _lastServerUpdate =
            _latestServerTimestamp(tasks);
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
            'No se pudieron leer los datos locales.';
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
      final tasks =
          await _repository.synchronize();

      if (!mounted) return;

      setState(() {
        _tasks = tasks;
        _isOffline = false;
        _lastServerUpdate =
            _latestServerTimestamp(tasks);
      });
    } catch (e) {
      final local =
          await _repository.getLocalTasks();

      if (!mounted) return;

      setState(() {
        _tasks = local;
        _isOffline = true;

        _errorMessage = local.isEmpty
            ? e
                .toString()
                .replaceFirst('Exception: ', '')
            : null;

        _lastServerUpdate =
            _latestServerTimestamp(local);
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

  // ============================================================
  // SEMANA 14 - UBICACIÓN NATIVA
  // ============================================================

  Future<void> _useLocation() async {
    // La explicación aparece solamente cuando el usuario
    // intenta utilizar la funcionalidad.
    final continueRequest =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Agregar ubicación',
          ),
          content: const Text(
            'La Agenda utilizará tu ubicación actual '
            'únicamente para asociarla a la tarea que '
            'estás creando. Puedes continuar usando '
            'la aplicación aunque no concedas este permiso.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (continueRequest != true) return;
    if (!mounted) return;

    // ----------------------------------------------------------
    // Comprobar servicio GPS por separado del permiso.
    // ----------------------------------------------------------

    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Ubicación desactivada',
            ),
            content: const Text(
              'El servicio de ubicación del teléfono '
              'está desactivado. Puedes continuar usando '
              'la Agenda sin ubicación o activar el '
              'servicio desde los ajustes.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child: const Text(
                  'Continuar sin ubicación',
                ),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(
                    dialogContext,
                  );

                  await Geolocator
                      .openLocationSettings();
                },
                child: const Text(
                  'Abrir ubicación',
                ),
              ),
            ],
          );
        },
      );

      return;
    }

    // ----------------------------------------------------------
    // Comprobar estado actual del permiso.
    // ----------------------------------------------------------

    var permission =
        await Geolocator.checkPermission();

    // Se solicita solamente al utilizar la función.
    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    // ----------------------------------------------------------
    // Permiso denegado.
    // ----------------------------------------------------------

    if (permission ==
        LocationPermission.denied) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Permiso denegado',
            ),
            content: const Text(
              'No se agregó la ubicación. '
              'Puedes continuar creando y consultando '
              'tareas normalmente.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child: const Text('Entendido'),
              ),
            ],
          );
        },
      );

      return;
    }

    // ----------------------------------------------------------
    // Permiso denegado permanentemente.
    // ----------------------------------------------------------

    if (permission ==
        LocationPermission.deniedForever) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Permiso bloqueado',
            ),
            content: const Text(
              'El permiso de ubicación fue denegado '
              'permanentemente. Puedes seguir usando '
              'la Agenda sin ubicación o habilitar '
              'el permiso desde los ajustes del sistema.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(
                    dialogContext,
                  );
                },
                child: const Text(
                  'Continuar sin ubicación',
                ),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(
                    dialogContext,
                  );

                  await permission_handler
                      .openAppSettings();
                },
                child: const Text(
                  'Abrir ajustes',
                ),
              ),
            ],
          );
        },
      );

      return;
    }

    // ----------------------------------------------------------
    // Permiso concedido: obtener coordenadas.
    // ----------------------------------------------------------

    if (!mounted) return;

    setState(() {
      _gettingLocation = true;
    });

    try {
      final position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
      });

      _showMessage(
        'Ubicación agregada correctamente.',
      );
    } catch (_) {
      _showMessage(
        'No fue posible obtener la ubicación. '
        'Puedes continuar creando la tarea sin ella.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _gettingLocation = false;
        });
      }
    }
  }

  void _removeLocation() {
    setState(() {
      _currentPosition = null;
    });

    _showMessage(
      'Ubicación eliminada de la tarea.',
    );
  }


  // ============================================================
  // SEMANA 14 - CAMARA NATIVA
  // ============================================================

  Future<void> _takePhoto() async {
    final continuar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tomar foto'),
        content: const Text(
          'La Agenda utilizara la camara unicamente para tomar una foto '
          'y asociarla a la tarea que estas creando. Puedes continuar '
          'usando la aplicacion aunque no concedas este permiso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (continuar != true || !mounted) return;

    var status = await permission_handler.Permission.camera.status;
    if (status.isDenied) {
      status = await permission_handler.Permission.camera.request();
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Permiso de camara bloqueado'),
          content: const Text(
            'El permiso de camara no esta disponible. Puedes seguir usando '
            'la Agenda sin foto o habilitar el permiso desde los ajustes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Continuar sin foto'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await permission_handler.openAppSettings();
              },
              child: const Text('Abrir ajustes'),
            ),
          ],
        ),
      );
      return;
    }

    if (!status.isGranted) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Permiso de camara denegado'),
          content: const Text(
            'No se tomo ninguna foto. Puedes continuar creando y '
            'sincronizando tareas normalmente.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _takingPhoto = true);
    try {
      final photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (photo == null) {
        _showMessage('No se tomo ninguna foto.');
        return;
      }
      setState(() => _taskPhoto = photo);
      _showMessage('Foto agregada correctamente.');
    } catch (_) {
      _showMessage('No fue posible abrir la camara. Puedes continuar sin foto.');
    } finally {
      if (mounted) setState(() => _takingPhoto = false);
    }
  }

  void _removePhoto() {
    setState(() => _taskPhoto = null);
    _showMessage('Foto eliminada de la tarea.');
  }

  // ============================================================
  // CREAR TAREA
  // ============================================================

  Future<void> _addTask() async {
    final title =
        _taskController.text.trim();

    if (title.isEmpty) {
      _showMessage(
        'Escribe una tarea primero.',
      );
      return;
    }

    final clientId =
        const Uuid().v4();

    // Por ahora guardamos las coordenadas dentro de description.
    // Así utilizamos la estructura existente de Semana 13 sin
    // romper SQLite ni el backend.
    String description = '';

    if (_currentPosition != null) {
      description =
          'Ubicación: '
          '${_currentPosition!.latitude.toStringAsFixed(6)}, '
          '${_currentPosition!.longitude.toStringAsFixed(6)}';
    }

    if (_taskPhoto != null) {
      if (description.isNotEmpty) description += '\n';
      description += 'Foto adjunta: ${_taskPhoto!.name}';
    }

    final task = <String, dynamic>{
      'id': clientId,
      'client_id': clientId,
      'title': title,
      'description': description,
      'is_completed': 0,
      'last_updated_server': null,
      'is_synced': 0,
    };

    try {
      await _repository
          .createTaskOffline(task);

      _taskController.clear();

      if (mounted) {
        setState(() {
          _currentPosition = null;
          _taskPhoto = null;
        });
      }

      await _loadLocal();

      if (!mounted) return;

      _showMessage(
        _isOffline
            ? 'Tarea guardada sin conexión. '
                'Se enviará al recuperar Internet.'
            : 'Tarea guardada. '
                'Sincronizando con el servidor...',
      );

      if (!_isOffline) {
        await _syncAndLoad();
      }
    } catch (e) {
      _showMessage(
        'No se pudo guardar la tarea.',
      );
    }
  }

  // ============================================================
  // FECHA DE SINCRONIZACIÓN
  // ============================================================

  String? _latestServerTimestamp(
    List<Tarea> tasks,
  ) {
    final dates = tasks
        .where(
          (task) =>
              task.updatedAt != null &&
              task.updatedAt!.isNotEmpty,
        )
        .map(
          (task) =>
              DateTime.tryParse(
            task.updatedAt!,
          ),
        )
        .whereType<DateTime>()
        .toList();

    if (dates.isEmpty) {
      return null;
    }

    dates.sort();

    return _formatDate(
      dates.last.toLocal(),
    );
  }

  String _formatDate(
    DateTime date,
  ) {
    String two(int value) =>
        value.toString().padLeft(2, '0');

    return '${two(date.day)}/'
        '${two(date.month)}/'
        '${date.year} '
        '${two(date.hour)}:'
        '${two(date.minute)}';
  }

  // ============================================================
  // CERRAR SESIÓN
  // ============================================================

  Future<void> _logout() async {
    await _authRepository.logout();
    await _repository.clearLocalData();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(),
      ),
      (_) => false,
    );
  }

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agenda de Tareas',
        ),
        actions: [
          IconButton(
            tooltip: 'Sincronizar',
            onPressed:
                _isSyncing
                    ? null
                    : _syncAndLoad,
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.sync,
                  ),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(
              Icons.logout,
            ),
          ),
        ],
      ),

      body: Column(
        children: [
          // ----------------------------------------------------
          // ESTADO DE CONEXIÓN
          // ----------------------------------------------------

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
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    _isOffline
                        ? 'Modo sin conexión · '
                            'mostrando datos locales'
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

          // ----------------------------------------------------
          // ÚLTIMA SINCRONIZACIÓN
          // ----------------------------------------------------

          if (_lastServerUpdate != null)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                0,
              ),
              child: Align(
                alignment:
                    Alignment.centerLeft,
                child: Text(
                  _isOffline
                      ? 'Datos del servidor actualizados '
                          'por última vez: '
                          '$_lastServerUpdate'
                      : 'Última actualización del servidor: '
                          '$_lastServerUpdate',
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),

          // ----------------------------------------------------
          // NUEVA TAREA
          // ----------------------------------------------------

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              8,
            ),
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
                      _addTask();
                    },
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                IconButton(
                  tooltip:
                      'Agregar tarea',
                  onPressed: _addTask,
                  icon: const Icon(
                    Icons.add_circle,
                    size: 40,
                  ),
                ),
              ],
            ),
          ),

          // ----------------------------------------------------
          // SEMANA 14 - BOTÓN DE UBICACIÓN
          // ----------------------------------------------------

          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              0,
              16,
              12,
            ),
            child: Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        _gettingLocation
                            ? null
                            : _useLocation,
                    icon: _gettingLocation
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                            ),
                          )
                        : const Icon(
                            Icons
                                .location_on,
                          ),
                    label: Text(
                      _currentPosition ==
                              null
                          ? 'Agregar ubicación'
                          : 'Ubicación agregada',
                    ),
                  ),
                ),

                if (_currentPosition !=
                    null) ...[
                  const SizedBox(
                    width: 8,
                  ),
                  IconButton(
                    tooltip:
                        'Eliminar ubicación',
                    onPressed:
                        _removeLocation,
                    icon: const Icon(
                      Icons.close,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ----------------------------------------------------
          // UBICACIÓN SELECCIONADA
          // ----------------------------------------------------

          if (_currentPosition != null)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                12,
              ),
              child: Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                decoration:
                    BoxDecoration(
                  border:
                      Border.all(
                    color:
                        Colors.green,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons
                          .check_circle,
                      color:
                          Colors.green,
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Expanded(
                      child: Text(
                        'Ubicación lista para '
                        'adjuntar a esta tarea.\n'
                        'Lat: '
                        '${_currentPosition!.latitude.toStringAsFixed(6)} '
                        '· Lon: '
                        '${_currentPosition!.longitude.toStringAsFixed(6)}',
                        style:
                            const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),


          // ----------------------------------------------------
          // SEMANA 14 - CAMARA
          // ----------------------------------------------------
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takingPhoto ? null : _takePhoto,
                    icon: _takingPhoto
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt),
                    label: Text(_taskPhoto == null ? 'Tomar foto' : 'Foto agregada'),
                  ),
                ),
                if (_taskPhoto != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Eliminar foto',
                    onPressed: _removePhoto,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ],
            ),
          ),

          if (_taskPhoto != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.green),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Foto lista para adjuntar a esta tarea.'),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_taskPhoto!.path),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ----------------------------------------------------
          // MENSAJE DE ERROR
          // ----------------------------------------------------

          if (_errorMessage != null)
            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 16,
              ),
              child: Text(
                _errorMessage!,
                style:
                    const TextStyle(
                  color: Colors.red,
                ),
              ),
            ),

          // ----------------------------------------------------
          // LISTA DE TAREAS
          // ----------------------------------------------------

          Expanded(
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : _tasks.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay tareas guardadas.',
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh:
                            _isOffline
                                ? _loadLocal
                                : _syncAndLoad,
                        child:
                            ListView.builder(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          itemCount:
                              _tasks.length,
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final task =
                                _tasks[index];

                            return Card(
                              margin:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal:
                                    12,
                                vertical: 6,
                              ),
                              child:
                                  ListTile(
                                leading:
                                    Icon(
                                  task.isSynced
                                      ? Icons
                                          .cloud_done
                                      : Icons
                                          .cloud_upload,
                                  color: task
                                          .isSynced
                                      ? Colors
                                          .green
                                      : Colors
                                          .orange,
                                ),
                                title: Text(
                                  task.titulo,
                                ),
                                subtitle:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      '${task.completada ? 'Completada' : 'Pendiente'} · '
                                      '${task.isSynced ? 'Sincronizada' : 'Pendiente de envío'}',
                                    ),

                                    if (task.descripcion?.isNotEmpty ?? false)
  Padding(
    padding: const EdgeInsets.only(
      top: 4,
    ),
    child: Text(
      task.descripcion ?? '',
      style: const TextStyle(
        fontSize: 12,
      ),
    ),
  ),
                                    ],
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