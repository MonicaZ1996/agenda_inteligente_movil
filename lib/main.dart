import 'package:flutter/material.dart';
import 'package:agenda_inteligente_movil/screens/login_screen.dart';
import 'package:agenda_inteligente_movil/theme/app_theme.dart';
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
      home: const LoginScreen(),
    );
  }
}