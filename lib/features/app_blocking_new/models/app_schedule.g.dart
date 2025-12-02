// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_schedule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppScheduleAdapter extends TypeAdapter<AppSchedule> {
  @override
  final int typeId = 2;

  @override
  AppSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSchedule(
      packageName: fields[0] as String,
      appName: fields[1] as String,
      startHour: fields[2] as int,
      startMinute: fields[3] as int,
      endHour: fields[4] as int,
      endMinute: fields[5] as int,
      isEnabled: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AppSchedule obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.packageName)
      ..writeByte(1)
      ..write(obj.appName)
      ..writeByte(2)
      ..write(obj.startHour)
      ..writeByte(3)
      ..write(obj.startMinute)
      ..writeByte(4)
      ..write(obj.endHour)
      ..writeByte(5)
      ..write(obj.endMinute)
      ..writeByte(6)
      ..write(obj.isEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
