class AppLaunchLimit {
  final String packageName;
  final int maxLaunches;
  final int currentLaunches;

  AppLaunchLimit({
    required this.packageName,
    required this.maxLaunches,
    required this.currentLaunches,
  });

  bool get isLimitReached => currentLaunches >= maxLaunches;
  int get remainingLaunches => maxLaunches - currentLaunches > 0 ? maxLaunches - currentLaunches : 0;
  double get progress => maxLaunches > 0 ? currentLaunches / maxLaunches : 0.0;

  Map<String, dynamic> toJson() => {
        'packageName': packageName,
        'maxLaunches': maxLaunches,
        'currentLaunches': currentLaunches,
      };

  factory AppLaunchLimit.fromJson(Map<String, dynamic> json) => AppLaunchLimit(
        packageName: json['packageName'] as String,
        maxLaunches: json['maxLaunches'] as int,
        currentLaunches: json['currentLaunches'] as int,
      );

  AppLaunchLimit copyWith({
    String? packageName,
    int? maxLaunches,
    int? currentLaunches,
  }) {
    return AppLaunchLimit(
      packageName: packageName ?? this.packageName,
      maxLaunches: maxLaunches ?? this.maxLaunches,
      currentLaunches: currentLaunches ?? this.currentLaunches,
    );
  }
}
