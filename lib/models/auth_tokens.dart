import 'package:json_annotation/json_annotation.dart';

part 'auth_tokens.g.dart';

@JsonSerializable()
class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory AuthTokens.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$AuthTokensFromJson(json);

  Map<String, dynamic> toJson() =>
      _$AuthTokensToJson(this);
}