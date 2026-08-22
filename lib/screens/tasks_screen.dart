import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../components/task_card.dart';
import '../components/state_display.dart';
import '../theme/app_theme.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  DisplayStateEnum _state = DisplayStateEnum.loading;
  List<dynamic> _tasks = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() {
      _state = DisplayStateEnum.loading;
      _errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse('http://localhost:5000/api/tareas'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _tasks = data;
          _state = data.isEmpty ? DisplayStateEnum.empty : DisplayStateEnum.content;
        });
      } else {
        setState(() {
          _errorMessage = 'Error del servidor: Status ${response.statusCode}';
          _state = DisplayStateEnum.error;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo conectar a la API local.\n($e)';
        _state = DisplayStateEnum.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda de Tareas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchTasks,
          )
        ],
      ),
      body: StateDisplay(
        state: _state,
        errorMessage: _errorMessage,
        onRetry: _fetchTasks,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: _tasks.length,
          itemBuilder: (context, index) {
            final task = _tasks[index];
            return TaskCard(
              title: task['titulo'] ?? task['nombre'] ?? 'Tarea sin título',
              subtitle: task['descripcion'] ?? 'Sin descripción',
              isCompleted: task['completada'] ?? false,
            );
          },
        ),
      ),
    );
  }
}