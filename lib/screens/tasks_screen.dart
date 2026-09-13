import 'package:flutter/material.dart';
import '../components/task_card.dart';
import '../components/state_display.dart';
import '../theme/app_theme.dart';
import '../data/repositories/task_repository.dart';
import '../models/tarea.dart'; // Importante: importar el modelo Tarea

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // ============================================================
  // REPOSITORY
  // ============================================================

  final TaskRepository _repository = TaskRepository();

  // ============================================================
  // ESTADO DE LA PANTALLA
  // ============================================================

  DisplayStateEnum _state = DisplayStateEnum.loading;

  // Cambiamos el tipo de la lista de Map<String, dynamic> a Tarea
  List<Tarea> _tasks = [];

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
      // El Repository nos entrega directamente List<Tarea>
      final tasks = await _repository.getTasks();

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
        _errorMessage = 'No se pudieron cargar las tareas.\n$e';

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
        title: const Text('Agenda de Tareas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar tareas',
            onPressed: _fetchTasks,
          ),
        ],
      ),
      body: StateDisplay(
        state: _state,
        errorMessage: _errorMessage,
        onRetry: _fetchTasks,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
          ),
          itemCount: _tasks.length,
          itemBuilder: (context, index) {
            final Tarea task = _tasks[index];

            // --------------------------------------------------
            // CAMPOS ACCEDIDOS DESDE EL MODELO TAREA
            // --------------------------------------------------

            final String title = task.titulo.isNotEmpty
                ? task.titulo
                : 'Tarea sin título';

            final String subtitle = 'Estado: ${task.estado}';

            final bool isCompleted =
                task.estado.toLowerCase() == 'completada' ||
                task.estado.toLowerCase() == 'completado';

            // --------------------------------------------------
            // TARJETA
            // --------------------------------------------------

            return TaskCard(
              title: title,
              subtitle: subtitle,
              isCompleted: isCompleted,
            );
          },
        ),
      ),
    );
  }
}