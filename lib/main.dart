import 'package:flutter/material.dart';

import 'config/api_config.dart';
import 'screens/login_screen.dart';
import 'screens/tasks_screen.dart';
import 'services/secure_storage_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ApiConfig.validate();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _hasSession() async {
    final refreshToken = await SecureStorageService.getRefreshToken();
    return refreshToken != null && refreshToken.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agenda Inteligente',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FutureBuilder<bool>(
        future: _hasSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return snapshot.data == true
              ? const TasksScreen()
              : const LoginScreen();
        },
      ),
    );
  }
}
