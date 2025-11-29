// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocking_session.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BlockingSessionAdapter extends TypeAdapter<BlockingSession> {
  @override
  final int typeId = 23;

  @override
  BlockingSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlockingSession(
      appPackage: fields[0] as String,
      startTime: fields[1] as DateTime,
      endTime: fields[2] as DateTime,
      durationMinutes: fields[3] as int,
      isActive: fields[4] as bool,
      bypassAttempts: fields[5] as int,
      completed: fields[6] as bool,
      completionPercentage: fields[7] as double,
      createdAt: fields[8] as DateTime,
      id: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BlockingSession obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.appPackage)
      ..writeByte(1)
      ..write(obj.startTime)
      ..writeByte(2)
      ..write(obj.endTime)
      ..writeByte(3)
      ..write(obj.durationMinutes)
      ..writeByte(4)
      ..write(obj.isActive)
      ..writeByte(5)
      ..write(obj.bypassAttempts)
      ..writeByte(6)
      ..write(obj.completed)
      ..writeByte(7)
      ..write(obj.completionPercentage)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockingSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BlockingSession _$BlockingSessionFromJson(Map<String, dynamic> json) =>
    BlockingSession(
      appPackage: json['appPackage'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      durationMinutes: (json['durationMinutes'] as num).toInt(),
      isActive: json['isActive'] as bool? ?? true,
      bypassAttempts: (json['bypassAttempts'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      completionPercentage:
          (json['completionPercentage'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      id: json['id'] as String?,
    );

Map<String, dynamic> _$BlockingSessionToJson(BlockingSession instance) =>
    <String, dynamic>{
      'appPackage': instance.appPackage,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime.toIso8601String(),
      'durationMinutes': instance.durationMinutes,
      'isActive': instance.isActive,
      'bypassAttempts': instance.bypassAttempts,
      'completed': instance.completed,
      'completionPercentage': instance.completionPercentage,
      'createdAt': instance.createdAt.toIso8601String(),
      'id': instance.id,
    };
