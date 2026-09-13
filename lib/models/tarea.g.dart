// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tarea.dart';

Tarea _$TareaFromJson(Map<String, dynamic> json) => Tarea(
      id: _idFromJson(json['id']),
      clientId: json['client_id'] as String?,
      titulo: json['titulo'] as String,
      descripcion: json['descripcion'] as String?,
      completada: json['completada'] as bool? ?? false,
      updatedAt: json['updated_at'] as String?,
      isSynced: json['is_synced'] as bool? ?? true,
    );

Map<String, dynamic> _$TareaToJson(Tarea instance) => <String, dynamic>{
      'id': instance.id,
      'client_id': instance.clientId,
      'titulo': instance.titulo,
      'descripcion': instance.descripcion,
      'completada': instance.completada,
      'updated_at': instance.updatedAt,
      'is_synced': instance.isSynced,
    };
