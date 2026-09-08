import '../../models/auth_tokens.dart';
import '../../models/usuario.dart';
import '../../services/secure_storage_service.dart';
import '../remote/auth_remote_data_source.dart';

class AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepository({
    AuthRemoteDataSource? remoteDataSource,
  }) : remoteDataSource =
            remoteDataSource ?? AuthRemoteDataSource();

  Future<Usuario> login({
    required String email,
    required String password,
  }) async {
    final result = await remoteDataSource.login(
      email: email,
      password: password,
    );

    final Usuario usuario = result.$1;
    final AuthTokens tokens = result.$2;

    await SecureStorageService.saveTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
    );

    return usuario;
  }

  Future<void> logout() async {
    await SecureStorageService.clearAll();
  }
}