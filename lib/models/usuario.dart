import 'package:json_annotation/json_annotation.dart';

part 'usuario.g.dart';

@JsonSerializable()
class Usuario {
  final String email;

  Usuario({
    required this.email,
  });

  factory Usuario.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$UsuarioFromJson(json);

  Map<String, dynamic> toJson() =>
      _$UsuarioToJson(this);
}