import 'package:dio/dio.dart';

import '../../../core/network/dio_client.dart';
import '../../../models/auth_tokens.dart';
import '../../../models/usuario.dart';
import '../../../config/api_config.dart';

class AuthRemoteDataSource {
  final Dio _dio = DioClient.instance.dio;

  Future<(Usuario, AuthTokens)> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiConfig.loginEndpoint,
      data: {
        'email': email,
        'password': password,
      },
    );

    final data = response.data as Map<String, dynamic>;

    final usuario = Usuario.fromJson(
      data['usuario'] as Map<String, dynamic>,
    );

    final tokens = AuthTokens.fromJson(
      data['tokens'] as Map<String, dynamic>,
    );

    return (usuario, tokens);
  }
}
