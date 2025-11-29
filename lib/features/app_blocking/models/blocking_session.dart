import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'blocking_session.g.dart';

@HiveType(typeId: 23)
@JsonSerializable()
class BlockingSession extends HiveObject {
  @HiveField(0)
  final String appPackage;

  @HiveField(1)
  final DateTime startTime;

  @HiveField(2)
  final DateTime endTime;

  @HiveField(3)
  final int durationMinutes;

  @HiveField(4)
  final bool isActive;

  @HiveField(5)
  final int bypassAttempts;

  @HiveField(6)
  final bool completed;

  @HiveField(7)
  final double completionPercentage;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final String id;

  BlockingSession({
    required this.appPackage,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.isActive = true,
    this.bypassAttempts = 0,
    this.completed = false,
    this.completionPercentage = 0.0,
    required this.createdAt,
    String? id,
  }) : id = id ?? const Uuid().v4();

  factory BlockingSession.fromJson(Map<String, dynamic> json) => _$BlockingSessionFromJson(json);
  Map<String, dynamic> toJson() => _$BlockingSessionToJson(this);

  BlockingSession copyWith({
    String? appPackage,
    DateTime? startTime,
    DateTime? endTime,
    int? durationMinutes,
    bool? isActive,
    int? bypassAttempts,
    bool? completed,
    double? completionPercentage,
    DateTime? createdAt,
    String? id,
  }) {
    return BlockingSession(
      appPackage: appPackage ?? this.appPackage,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isActive: isActive ?? this.isActive,
      bypassAttempts: bypassAttempts ?? this.bypassAttempts,
      completed: completed ?? this.completed,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      createdAt: createdAt ?? this.createdAt,
      id: id ?? this.id,
    );
  }

  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(endTime)) return Duration.zero;
    return endTime.difference(now);
  }

  Duration get totalDuration => Duration(minutes: durationMinutes);

  bool get isExpired => DateTime.now().isAfter(endTime);
}