import 'package:json_annotation/json_annotation.dart';

part 'tarea.g.dart';

String _idFromJson(Object? value) => value?.toString() ?? '';

@JsonSerializable()
class Tarea {
  @JsonKey(fromJson: _idFromJson)
  final String id;

  @JsonKey(name: 'client_id')
  final String? clientId;

  final String titulo;
  final String? descripcion;

  @JsonKey(name: 'completada')
  final bool completada;

  @JsonKey(name: 'updated_at')
  final String? updatedAt;

  @JsonKey(name: 'is_synced', defaultValue: true)
  final bool isSynced;

  Tarea({
    required this.id,
    this.clientId,
    required this.titulo,
    this.descripcion,
    this.completada = false,
    this.updatedAt,
    this.isSynced = true,
  });

  factory Tarea.fromJson(Map<String, dynamic> json) => _$TareaFromJson(json);

  Map<String, dynamic> toJson() => _$TareaToJson(this);
}
