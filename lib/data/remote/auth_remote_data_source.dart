import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../../models/auth_tokens.dart';
import '../../models/usuario.dart';
import '../../config/api_config.dart';

class AuthRemoteDataSource {
  final Dio _dio = DioClient.instance.dio;

  Future<(Usuario, AuthTokens)> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      ApiConfig.loginEndpoint,
      data: {'email': email, 'password': password},
    );

    final data = Map<String, dynamic>.from(response.data as Map);
    final usuario = Usuario.fromJson(
      Map<String, dynamic>.from(data['usuario'] as Map),
    );
    final tokens = AuthTokens.fromJson(
      Map<String, dynamic>.from(data['tokens'] as Map),
    );

    return (usuario, tokens);
  }
}
