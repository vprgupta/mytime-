import 'package:hive/hive.dart';

part 'app_blocking_settings.g.dart';

@HiveType(typeId: 10)
class AppBlockingSettings extends HiveObject {
  @HiveField(0)
  bool isToggleModeEnabled;

  @HiveField(1)
  bool isNamingLimiterEnabled;

  @HiveField(2)
  String customScreenName;

  @HiveField(3)
  List<String> favoriteApps;

  @HiveField(4)
  int defaultBlockDuration;

  @HiveField(5)
  bool enableQuickActions;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime updatedAt;

  AppBlockingSettings({
    this.isToggleModeEnabled = false,
    this.isNamingLimiterEnabled = false,
    this.customScreenName = '',
    this.favoriteApps = const [],
    this.defaultBlockDuration = 60,
    this.enableQuickActions = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  AppBlockingSettings copyWith({
    bool? isToggleModeEnabled,
    bool? isNamingLimiterEnabled,
    String? customScreenName,
    List<String>? favoriteApps,
    int? defaultBlockDuration,
    bool? enableQuickActions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppBlockingSettings(
      isToggleModeEnabled: isToggleModeEnabled ?? this.isToggleModeEnabled,
      isNamingLimiterEnabled: isNamingLimiterEnabled ?? this.isNamingLimiterEnabled,
      customScreenName: customScreenName ?? this.customScreenName,
      favoriteApps: favoriteApps ?? this.favoriteApps,
      defaultBlockDuration: defaultBlockDuration ?? this.defaultBlockDuration,
      enableQuickActions: enableQuickActions ?? this.enableQuickActions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isToggleModeEnabled': isToggleModeEnabled,
      'isNamingLimiterEnabled': isNamingLimiterEnabled,
      'customScreenName': customScreenName,
      'favoriteApps': favoriteApps,
      'defaultBlockDuration': defaultBlockDuration,
      'enableQuickActions': enableQuickActions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppBlockingSettings.fromJson(Map<String, dynamic> json) {
    return AppBlockingSettings(
      isToggleModeEnabled: json['isToggleModeEnabled'] ?? false,
      isNamingLimiterEnabled: json['isNamingLimiterEnabled'] ?? false,
      customScreenName: json['customScreenName'] ?? '',
      favoriteApps: List<String>.from(json['favoriteApps'] ?? []),
      defaultBlockDuration: json['defaultBlockDuration'] ?? 60,
      enableQuickActions: json['enableQuickActions'] ?? true,
      createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  @override
  String toString() {
    return 'AppBlockingSettings(toggleMode: $isToggleModeEnabled, namingLimiter: $isNamingLimiterEnabled, customName: $customScreenName)';
  }
}