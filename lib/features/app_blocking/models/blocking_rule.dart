import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:uuid/uuid.dart';

part 'blocking_rule.g.dart';

@HiveType(typeId: 21)
@JsonSerializable()
class BlockingRule extends HiveObject {
  @HiveField(0)
  final String name;

  @HiveField(1)
  final String appPackage;

  @HiveField(2)
  final String ruleType; // 'daily', 'weekly', 'custom'

  @HiveField(3)
  final String? startTime; // Stored as "HH:mm"

  @HiveField(4)
  final String? endTime; // Stored as "HH:mm"

  @HiveField(5)
  final List<String> daysOfWeek;

  @HiveField(6)
  final int? durationMinutes;

  @HiveField(7)
  final bool isActive;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  final String id;

  BlockingRule({
    required this.name,
    required this.appPackage,
    required this.ruleType,
    this.startTime,
    this.endTime,
    this.daysOfWeek = const [],
    this.durationMinutes,
    this.isActive = true,
    required this.createdAt,
    String? id,
  }) : id = id ?? const Uuid().v4();

  factory BlockingRule.fromJson(Map<String, dynamic> json) => _$BlockingRuleFromJson(json);
  Map<String, dynamic> toJson() => _$BlockingRuleToJson(this);

  BlockingRule copyWith({
    String? name,
    String? appPackage,
    String? ruleType,
    String? startTime,
    String? endTime,
    List<String>? daysOfWeek,
    int? durationMinutes,
    bool? isActive,
    DateTime? createdAt,
    String? id,
  }) {
    return BlockingRule(
      name: name ?? this.name,
      appPackage: appPackage ?? this.appPackage,
      ruleType: ruleType ?? this.ruleType,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      id: id ?? this.id,
    );
  }

  TimeOfDay? get startTimeOfDay {
    if (startTime == null) return null;
    final parts = startTime!.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  TimeOfDay? get endTimeOfDay {
    if (endTime == null) return null;
    final parts = endTime!.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  bool shouldTriggerToday() {
    final now = DateTime.now();
    final today = _getDayName(now.weekday);
    
    switch (ruleType) {
      case 'daily':
        return true;
      case 'weekly':
        return daysOfWeek.contains(today);
      default:
        return false;
    }
  }

  String _getDayName(int weekday) {
    const days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    return days[weekday - 1];
  }
}