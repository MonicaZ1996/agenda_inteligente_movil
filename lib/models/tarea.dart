import 'package:json_annotation/json_annotation.dart';

part 'tarea.g.dart';

@JsonSerializable()
class Tarea {
  final String id;

  @JsonKey(name: 'client_id')
  final String? clientId;

  final String titulo;

  final String? descripcion;

  final String estado;

  @JsonKey(name: 'completada')
  final bool completada;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  Tarea({
    required this.id,
    this.clientId,
    required this.titulo,
    this.descripcion,
    this.estado = 'Pendiente',
    this.completada = false,
    this.updatedAt,
  });

  factory Tarea.fromJson(
    Map<String, dynamic> json,
  ) {
    return Tarea(
      id: json['id'].toString(),
      clientId: json['client_id']?.toString(),
      titulo:
          json['titulo']?.toString() ??
          json['title']?.toString() ??
          'Tarea sin título',
      descripcion:
          json['descripcion']?.toString() ??
          json['description']?.toString(),
      estado:
          json['estado']?.toString() ??
          'Pendiente',
      completada:
          json['completada'] == true ||
          json['completada'] == 1 ||
          json['is_completed'] == 1,
      updatedAt:
          json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() =>
      _$TareaToJson(this);
}