// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocking_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BlockingRuleAdapter extends TypeAdapter<BlockingRule> {
  @override
  final int typeId = 21;

  @override
  BlockingRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlockingRule(
      name: fields[0] as String,
      appPackage: fields[1] as String,
      ruleType: fields[2] as String,
      startTime: fields[3] as String?,
      endTime: fields[4] as String?,
      daysOfWeek: (fields[5] as List).cast<String>(),
      durationMinutes: fields[6] as int?,
      isActive: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      id: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BlockingRule obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.appPackage)
      ..writeByte(2)
      ..write(obj.ruleType)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.daysOfWeek)
      ..writeByte(6)
      ..write(obj.durationMinutes)
      ..writeByte(7)
      ..write(obj.isActive)
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
      other is BlockingRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BlockingRule _$BlockingRuleFromJson(Map<String, dynamic> json) => BlockingRule(
      name: json['name'] as String,
      appPackage: json['appPackage'] as String,
      ruleType: json['ruleType'] as String,
      startTime: json['startTime'] as String?,
      endTime: json['endTime'] as String?,
      daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      durationMinutes: (json['durationMinutes'] as num?)?.toInt(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      id: json['id'] as String?,
    );

Map<String, dynamic> _$BlockingRuleToJson(BlockingRule instance) =>
    <String, dynamic>{
      'name': instance.name,
      'appPackage': instance.appPackage,
      'ruleType': instance.ruleType,
      'startTime': instance.startTime,
      'endTime': instance.endTime,
      'daysOfWeek': instance.daysOfWeek,
      'durationMinutes': instance.durationMinutes,
      'isActive': instance.isActive,
      'createdAt': instance.createdAt.toIso8601String(),
      'id': instance.id,
    };
