import 'package:flutter/material.dart';
import '../components/task_card.dart';
import '../components/state_display.dart';
import '../theme/app_theme.dart';
import '../data/repositories/task_repository.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() =>
      _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // ============================================================
  // REPOSITORY
  // ============================================================

  final TaskRepository _repository =
      TaskRepository();

  // ============================================================
  // ESTADO DE LA PANTALLA
  // ============================================================

  DisplayStateEnum _state =
      DisplayStateEnum.loading;

  List<Map<String, dynamic>> _tasks = [];

  String? _errorMessage;

  // ============================================================
  // INICIALIZAR
  // ============================================================

  @override
  void initState() {
    super.initState();

    _fetchTasks();
  }

  // ============================================================
  // OBTENER TAREAS
  // ============================================================

  Future<void> _fetchTasks() async {
    if (!mounted) return;

    setState(() {
      _state = DisplayStateEnum.loading;
      _errorMessage = null;
    });

    try {
      // El Repository se encarga de:
      //
      // 1. Intentar obtener las tareas desde el servidor.
      // 2. Guardarlas en SQLite.
      // 3. Si no hay conexión, utilizar las tareas locales.
      final tasks =
          await _repository.getTasks();

      if (!mounted) return;

      setState(() {
        _tasks = tasks;

        _state = tasks.isEmpty
            ? DisplayStateEnum.empty
            : DisplayStateEnum.content;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'No se pudieron cargar las tareas.\n$e';

        _state = DisplayStateEnum.error;
      });
    }
  }

  // ============================================================
  // CONSTRUIR INTERFAZ
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Agenda de Tareas'),

        actions: [
          IconButton(
            icon:
                const Icon(Icons.refresh),

            tooltip:
                'Actualizar tareas',

            onPressed:
                _fetchTasks,
          ),
        ],
      ),

      body: StateDisplay(
        state: _state,

        errorMessage:
            _errorMessage,

        onRetry:
            _fetchTasks,

        child: ListView.builder(
          padding:
              const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
          ),

          itemCount:
              _tasks.length,

          itemBuilder:
              (context, index) {
            final task =
                _tasks[index];

            // --------------------------------------------------
            // TÍTULO
            // --------------------------------------------------

            final String title =
                task['titulo']
                        ?.toString() ??
                    task['nombre']
                        ?.toString() ??
                    task['title']
                        ?.toString() ??
                    'Tarea sin título';

            // --------------------------------------------------
            // DESCRIPCIÓN
            // --------------------------------------------------

            final String subtitle =
                task['descripcion']
                        ?.toString() ??
                    task['description']
                        ?.toString() ??
                    'Sin descripción';

            // --------------------------------------------------
            // ESTADO COMPLETADA
            // --------------------------------------------------

            final dynamic completedValue =
                task['completada'] ??
                    task['is_completed'] ??
                    false;

            final bool isCompleted =
                completedValue == true ||
                completedValue == 1 ||
                completedValue
                        .toString()
                        .toLowerCase() ==
                    'true';

            // --------------------------------------------------
            // TARJETA
            // --------------------------------------------------

            return TaskCard(
              title: title,

              subtitle: subtitle,

              isCompleted:
                  isCompleted,
            );
          },
        ),
      ),
    );
  }
}