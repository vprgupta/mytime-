import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'blocked_app.g.dart';

@HiveType(typeId: 19)
@JsonSerializable()
class BlockedApp extends HiveObject {
  @HiveField(0)
  final String packageName;

  @HiveField(1)
  final String appName;

  @HiveField(2)
  final String? iconPath;

  @HiveField(3)
  final bool isActive;

  @HiveField(4)
  final int blockCount;

  @HiveField(5)
  final int totalBlockedTime;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  BlockedApp({
    required this.packageName,
    required this.appName,
    this.iconPath,
    this.isActive = false,
    this.blockCount = 0,
    this.totalBlockedTime = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BlockedApp.fromJson(Map<String, dynamic> json) => _$BlockedAppFromJson(json);
  Map<String, dynamic> toJson() => _$BlockedAppToJson(this);

  BlockedApp copyWith({
    String? packageName,
    String? appName,
    String? iconPath,
    bool? isActive,
    int? blockCount,
    int? totalBlockedTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BlockedApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      iconPath: iconPath ?? this.iconPath,
      isActive: isActive ?? this.isActive,
      blockCount: blockCount ?? this.blockCount,
      totalBlockedTime: totalBlockedTime ?? this.totalBlockedTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}