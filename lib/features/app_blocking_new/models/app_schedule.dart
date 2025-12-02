import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'app_schedule.g.dart';

@HiveType(typeId: 2)
class AppSchedule {
  @HiveField(0)
  final String packageName;

  @HiveField(1)
  final String appName;

  @HiveField(2)
  final int startHour;

  @HiveField(3)
  final int startMinute;

  @HiveField(4)
  final int endHour;

  @HiveField(5)
  final int endMinute;

  @HiveField(6)
  final bool isEnabled;

  AppSchedule({
    required this.packageName,
    required this.appName,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.isEnabled = true,
  });

  TimeOfDay get startTime => TimeOfDay(hour: startHour, minute: startMinute);
  TimeOfDay get endTime => TimeOfDay(hour: endHour, minute: endMinute);
}
