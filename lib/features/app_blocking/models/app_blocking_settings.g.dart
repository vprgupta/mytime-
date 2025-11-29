// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_blocking_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppBlockingSettingsAdapter extends TypeAdapter<AppBlockingSettings> {
  @override
  final int typeId = 10;

  @override
  AppBlockingSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppBlockingSettings(
      isToggleModeEnabled: fields[0] as bool,
      isNamingLimiterEnabled: fields[1] as bool,
      customScreenName: fields[2] as String,
      favoriteApps: (fields[3] as List).cast<String>(),
      defaultBlockDuration: fields[4] as int,
      enableQuickActions: fields[5] as bool,
      createdAt: fields[6] as DateTime?,
      updatedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AppBlockingSettings obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.isToggleModeEnabled)
      ..writeByte(1)
      ..write(obj.isNamingLimiterEnabled)
      ..writeByte(2)
      ..write(obj.customScreenName)
      ..writeByte(3)
      ..write(obj.favoriteApps)
      ..writeByte(4)
      ..write(obj.defaultBlockDuration)
      ..writeByte(5)
      ..write(obj.enableQuickActions)
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
      other is AppBlockingSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
