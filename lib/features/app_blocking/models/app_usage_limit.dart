import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'app_usage_limit.g.dart';

@HiveType(typeId: 20)
@JsonSerializable()
class AppUsageLimit extends HiveObject {
  @HiveField(0)
  final String packageName;

  @HiveField(1)
  final String appName;

  @HiveField(2)
  final int initialLimitMinutes; // Original limit set by user

  @HiveField(3)
  final int currentLimitMinutes; // Current limit (decreases daily)

  @HiveField(4)
  final int usedMinutesToday; // Minutes used today

  @HiveField(5)
  final DateTime lastResetDate; // Last date when limit was reset

  @HiveField(6)
  final bool isActive; // Whether limit is currently active

  @HiveField(7)
  final bool isBlocked; // Whether app is blocked for today

  @HiveField(8)
  final bool hasCommitment; // Whether limit has commitment mode enabled

  @HiveField(9)
  final int consecutiveDays; // Days since limit was set

  @HiveField(10)
  final DateTime createdAt;

  @HiveField(11)
  final DateTime updatedAt;

  AppUsageLimit({
    required this.packageName,
    required this.appName,
    required this.initialLimitMinutes,
    required this.currentLimitMinutes,
    this.usedMinutesToday = 0,
    required this.lastResetDate,
    this.isActive = true,
    this.isBlocked = false,
    this.hasCommitment = false,
    this.consecutiveDays = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppUsageLimit.fromJson(Map<String, dynamic> json) => _$AppUsageLimitFromJson(json);
  Map<String, dynamic> toJson() => _$AppUsageLimitToJson(this);

  // Check if limit is exceeded for today
  bool get isLimitExceeded => usedMinutesToday >= currentLimitMinutes;

  // Get remaining minutes for today
  int get remainingMinutes => (currentLimitMinutes - usedMinutesToday).clamp(0, currentLimitMinutes);

  // Check if it's a new day and limit should be reset
  bool get shouldResetToday {
    final today = DateTime.now();
    return today.day != lastResetDate.day || 
           today.month != lastResetDate.month || 
           today.year != lastResetDate.year;
  }

  AppUsageLimit copyWith({
    String? packageName,
    String? appName,
    int? initialLimitMinutes,
    int? currentLimitMinutes,
    int? usedMinutesToday,
    DateTime? lastResetDate,
    bool? isActive,
    bool? isBlocked,
    bool? hasCommitment,
    int? consecutiveDays,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUsageLimit(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      initialLimitMinutes: initialLimitMinutes ?? this.initialLimitMinutes,
      currentLimitMinutes: currentLimitMinutes ?? this.currentLimitMinutes,
      usedMinutesToday: usedMinutesToday ?? this.usedMinutesToday,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      isActive: isActive ?? this.isActive,
      isBlocked: isBlocked ?? this.isBlocked,
      hasCommitment: hasCommitment ?? this.hasCommitment,
      consecutiveDays: consecutiveDays ?? this.consecutiveDays,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}