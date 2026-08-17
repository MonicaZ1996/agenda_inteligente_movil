import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Agenda Inteligente Móvil',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ApiTestScreen(),
    );
  }
}

class ApiTestScreen extends StatefulWidget {
  const ApiTestScreen({super.key});

  @override
  State<ApiTestScreen> createState() => _ApiTestScreenState();
}

class _ApiTestScreenState extends State<ApiTestScreen> {
  String _estado = "Presiona el botón para probar conexión";
  bool _cargando = false;

  Future<void> probarConexion() async {
    setState(() => _cargando = true);
    try {
      // Si tu backend tiene otra ruta como '/api/tareas', cámbiala aquí
      final response = await http.get(Uri.parse('http://localhost:5000/api/tareas'));

      if (response.statusCode == 200) {
        setState(() => _estado = "¡Conexión Exitosa (200 OK)!\n\nRespuesta del Backend:\n${response.body}");
      } else {
        setState(() => _estado = "Respuesta del Servidor HTTP: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _estado = "Error al conectar con la API:\n$e");
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taller Sem 9 - Conexión API'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: probarConexion,
                icon: const Icon(Icons.sync),
                label: const Text('Probar Conexión a API Local'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              const SizedBox(height: 30),
              _cargando
                  ? const CircularProgressIndicator()
                  : Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          _estado,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}