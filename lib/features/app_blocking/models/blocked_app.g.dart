// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blocked_app.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BlockedAppAdapter extends TypeAdapter<BlockedApp> {
  @override
  final int typeId = 19;

  @override
  BlockedApp read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlockedApp(
      packageName: fields[0] as String,
      appName: fields[1] as String,
      iconPath: fields[2] as String?,
      isActive: fields[3] as bool,
      blockCount: fields[4] as int,
      totalBlockedTime: fields[5] as int,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, BlockedApp obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.packageName)
      ..writeByte(1)
      ..write(obj.appName)
      ..writeByte(2)
      ..write(obj.iconPath)
      ..writeByte(3)
      ..write(obj.isActive)
      ..writeByte(4)
      ..write(obj.blockCount)
      ..writeByte(5)
      ..write(obj.totalBlockedTime)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlockedAppAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BlockedApp _$BlockedAppFromJson(Map<String, dynamic> json) => BlockedApp(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String,
      iconPath: json['iconPath'] as String?,
      isActive: json['isActive'] as bool? ?? false,
      blockCount: (json['blockCount'] as num?)?.toInt() ?? 0,
      totalBlockedTime: (json['totalBlockedTime'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$BlockedAppToJson(BlockedApp instance) =>
    <String, dynamic>{
      'packageName': instance.packageName,
      'appName': instance.appName,
      'iconPath': instance.iconPath,
      'isActive': instance.isActive,
      'blockCount': instance.blockCount,
      'totalBlockedTime': instance.totalBlockedTime,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };
