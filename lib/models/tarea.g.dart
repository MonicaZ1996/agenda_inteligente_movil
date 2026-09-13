// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tarea.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Tarea _$TareaFromJson(Map<String, dynamic> json) => Tarea(
  id: json['id'] as String,
  clientId: json['client_id'] as String?,
  titulo: json['titulo'] as String,
  descripcion: json['descripcion'] as String?,
  estado: json['estado'] as String? ?? 'Pendiente',
  completada: json['completada'] as bool? ?? false,
  updatedAt: json['updated_at'] as String?,
);

Map<String, dynamic> _$TareaToJson(Tarea instance) => <String, dynamic>{
  'id': instance.id,
  'client_id': instance.clientId,
  'titulo': instance.titulo,
  'descripcion': instance.descripcion,
  'estado': instance.estado,
  'completada': instance.completada,
  'updated_at': instance.updatedAt,
};
