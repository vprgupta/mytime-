// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bypass_attempt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BypassAttemptAdapter extends TypeAdapter<BypassAttempt> {
  @override
  final int typeId = 22;

  @override
  BypassAttempt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BypassAttempt(
      sessionId: fields[0] as int?,
      attemptType: fields[1] as String,
      timestamp: fields[2] as DateTime,
      wasSuccessful: fields[3] as bool,
      penaltyApplied: fields[4] as String?,
      additionalInfo: fields[5] as String?,
      appPackage: fields[6] as String,
      id: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, BypassAttempt obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.sessionId)
      ..writeByte(1)
      ..write(obj.attemptType)
      ..writeByte(2)
      ..write(obj.timestamp)
      ..writeByte(3)
      ..write(obj.wasSuccessful)
      ..writeByte(4)
      ..write(obj.penaltyApplied)
      ..writeByte(5)
      ..write(obj.additionalInfo)
      ..writeByte(6)
      ..write(obj.appPackage)
      ..writeByte(7)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BypassAttemptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BypassAttempt _$BypassAttemptFromJson(Map<String, dynamic> json) =>
    BypassAttempt(
      sessionId: (json['sessionId'] as num?)?.toInt(),
      attemptType: json['attemptType'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      wasSuccessful: json['wasSuccessful'] as bool? ?? false,
      penaltyApplied: json['penaltyApplied'] as String?,
      additionalInfo: json['additionalInfo'] as String?,
      appPackage: json['appPackage'] as String,
      id: json['id'] as String?,
    );

Map<String, dynamic> _$BypassAttemptToJson(BypassAttempt instance) =>
    <String, dynamic>{
      'sessionId': instance.sessionId,
      'attemptType': instance.attemptType,
      'timestamp': instance.timestamp.toIso8601String(),
      'wasSuccessful': instance.wasSuccessful,
      'penaltyApplied': instance.penaltyApplied,
      'additionalInfo': instance.additionalInfo,
      'appPackage': instance.appPackage,
      'id': instance.id,
    };
