import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'bypass_attempt.g.dart';

@HiveType(typeId: 22)
@JsonSerializable()
class BypassAttempt extends HiveObject {
  @HiveField(0)
  final int? sessionId;

  @HiveField(1)
  final String attemptType; // 'uninstall', 'force_stop', 'settings', 'time_change'

  @HiveField(2)
  final DateTime timestamp;

  @HiveField(3)
  final bool wasSuccessful;

  @HiveField(4)
  final String? penaltyApplied; // 'streak_reduction', 'time_extension', 'xp_penalty'

  @HiveField(5)
  final String? additionalInfo;

  @HiveField(6)
  final String appPackage;

  @HiveField(7)
  final String id;

  BypassAttempt({
    this.sessionId,
    required this.attemptType,
    required this.timestamp,
    this.wasSuccessful = false,
    this.penaltyApplied,
    this.additionalInfo,
    required this.appPackage,
    String? id,
  }) : id = id ?? const Uuid().v4();

  factory BypassAttempt.fromJson(Map<String, dynamic> json) => _$BypassAttemptFromJson(json);
  Map<String, dynamic> toJson() => _$BypassAttemptToJson(this);

  BypassAttempt copyWith({
    int? sessionId,
    String? attemptType,
    DateTime? timestamp,
    bool? wasSuccessful,
    String? penaltyApplied,
    String? additionalInfo,
    String? appPackage,
    String? id,
  }) {
    return BypassAttempt(
      sessionId: sessionId ?? this.sessionId,
      attemptType: attemptType ?? this.attemptType,
      timestamp: timestamp ?? this.timestamp,
      wasSuccessful: wasSuccessful ?? this.wasSuccessful,
      penaltyApplied: penaltyApplied ?? this.penaltyApplied,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      appPackage: appPackage ?? this.appPackage,
      id: id ?? this.id,
    );
  }

  String get severityLevel {
    switch (attemptType) {
      case 'settings':
      case 'time_change':
        return 'Minor';
      case 'force_stop':
      case 'uninstall':
        return 'Major';
      case 'root_access':
      case 'system_modification':
        return 'Critical';
      default:
        return 'Minor';
    }
  }
}