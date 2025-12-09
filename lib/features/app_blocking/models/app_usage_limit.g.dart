// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_usage_limit.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppUsageLimitAdapter extends TypeAdapter<AppUsageLimit> {
  @override
  final int typeId = 20;

  @override
  AppUsageLimit read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppUsageLimit(
      packageName: fields[0] as String,
      appName: fields[1] as String,
      initialLimitMinutes: fields[2] as int,
      currentLimitMinutes: fields[3] as int,
      usedMinutesToday: fields[4] as int,
      lastResetDate: fields[5] as DateTime,
      isActive: fields[6] as bool,
      isBlocked: fields[7] as bool,
      hasCommitment: fields[8] as bool,
      consecutiveDays: fields[9] as int,
      createdAt: fields[10] as DateTime,
      updatedAt: fields[11] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AppUsageLimit obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.packageName)
      ..writeByte(1)
      ..write(obj.appName)
      ..writeByte(2)
      ..write(obj.initialLimitMinutes)
      ..writeByte(3)
      ..write(obj.currentLimitMinutes)
      ..writeByte(4)
      ..write(obj.usedMinutesToday)
      ..writeByte(5)
      ..write(obj.lastResetDate)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.isBlocked)
      ..writeByte(8)
      ..write(obj.hasCommitment)
      ..writeByte(9)
      ..write(obj.consecutiveDays)
      ..writeByte(10)
      ..write(obj.createdAt)
      ..writeByte(11)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUsageLimitAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppUsageLimit _$AppUsageLimitFromJson(Map<String, dynamic> json) =>
    AppUsageLimit(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String,
      initialLimitMinutes: (json['initialLimitMinutes'] as num).toInt(),
      currentLimitMinutes: (json['currentLimitMinutes'] as num).toInt(),
      usedMinutesToday: (json['usedMinutesToday'] as num?)?.toInt() ?? 0,
      lastResetDate: DateTime.parse(json['lastResetDate'] as String),
      isActive: json['isActive'] as bool? ?? true,
      isBlocked: json['isBlocked'] as bool? ?? false,
      hasCommitment: json['hasCommitment'] as bool? ?? false,
      consecutiveDays: (json['consecutiveDays'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$AppUsageLimitToJson(AppUsageLimit instance) =>
    <String, dynamic>{
      'packageName': instance.packageName,
      'appName': instance.appName,
      'initialLimitMinutes': instance.initialLimitMinutes,
      'currentLimitMinutes': instance.currentLimitMinutes,
      'usedMinutesToday': instance.usedMinutesToday,
      'lastResetDate': instance.lastResetDate.toIso8601String(),
      'isActive': instance.isActive,
      'isBlocked': instance.isBlocked,
      'hasCommitment': instance.hasCommitment,
      'consecutiveDays': instance.consecutiveDays,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
