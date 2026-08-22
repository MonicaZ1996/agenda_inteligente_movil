import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/tasks_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda Inteligente',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const TasksScreen(),
    );
  }
}