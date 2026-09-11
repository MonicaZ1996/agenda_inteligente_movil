import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/network/dio_client.dart';

class AuthTestScreen extends StatefulWidget {
  const AuthTestScreen({super.key});

  @override
  State<AuthTestScreen> createState() => _AuthTestScreenState();
}

class _AuthTestScreenState extends State<AuthTestScreen> {
  final Dio _dio = DioClient.instance.dio;

  String _resultado = 'Todavía no se ha realizado ninguna petición.';
  bool _loading = false;

  Future<void> _obtenerTareas() async {
    setState(() {
      _loading = true;
      _resultado = 'Realizando petición...';
    });

    try {
      final response = await _dio.get('/api/tareas');

      setState(() {
        _resultado =
            'ÉXITO\n\n'
            'Código: ${response.statusCode}\n\n'
            'Respuesta:\n${response.data}';
      });
    } on DioException catch (e) {
      setState(() {
        _resultado =
            'ERROR\n\n'
            'Código: ${e.response?.statusCode}\n\n'
            'Mensaje:\n${e.response?.data ?? e.message}';
      });
    } catch (e) {
      setState(() {
        _resultado = 'ERROR:\n$e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prueba de autenticación'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Prueba JWT + Refresh Token',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _loading ? null : _obtenerTareas,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'OBTENER TAREAS',
                      ),
              ),
            ),

            const SizedBox(height: 30),

            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _resultado,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}