import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:usage_stats/usage_stats.dart';
import 'package:flutter/foundation.dart';

class UsageStatsService {
  static final UsageStatsService _instance = UsageStatsService._internal();
  factory UsageStatsService() => _instance;
  UsageStatsService._internal();

  static const MethodChannel _channel = MethodChannel('usage_stats');
  
  Timer? _monitoringTimer;
  String? _currentForegroundApp;
  final StreamController<String> _appLaunchController = StreamController<String>.broadcast();
  final StreamController<String> _foregroundAppController = StreamController<String>.broadcast();
  
  bool _isMonitoring = false;

  /// Stream of app launches
  Stream<String> get appLaunches => _appLaunchController.stream;
  
  /// Stream of foreground app changes
  Stream<String> get foregroundAppChanges => _foregroundAppController.stream;
  
  /// Current foreground app
  String? get currentForegroundApp => _currentForegroundApp;

  /// Initialize the service
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    
    await _setupMethodChannel();
  }

  /// Setup method channel for native communication
  Future<void> _setupMethodChannel() async {
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onAppLaunched':
          final packageName = call.arguments['packageName'] as String;
          _appLaunchController.add(packageName);
          break;
        case 'onForegroundAppChanged':
          final packageName = call.arguments['packageName'] as String;
          _currentForegroundApp = packageName;
          _foregroundAppController.add(packageName);
          break;
      }
    });
  }

  /// Start monitoring app usage
  Future<void> startMonitoring() async {
    if (_isMonitoring || !Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('startMonitoring');
      _isMonitoring = true;
      
      // Fallback polling for devices that don't support real-time monitoring
      _startPollingFallback();
    } catch (e) {
      debugPrint('Error starting usage monitoring: $e');
      // Use fallback polling method
      _startPollingFallback();
    }
  }

  /// Stop monitoring app usage
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;
    
    _isMonitoring = false;
    _monitoringTimer?.cancel();
    
    try {
      await _channel.invokeMethod('stopMonitoring');
    } catch (e) {
      debugPrint('Error stopping usage monitoring: $e');
    }
  }

  /// Start polling fallback for older devices
  void _startPollingFallback() {
    _monitoringTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _checkForegroundApp();
    });
  }

  /// Check current foreground app using polling
  Future<void> _checkForegroundApp() async {
    try {
      final currentApp = await getCurrentForegroundApp();
      if (currentApp != null && currentApp != _currentForegroundApp) {
        _currentForegroundApp = currentApp;
        _foregroundAppController.add(currentApp);
      }
    } catch (e) {
      // Ignore errors in polling
    }
  }

  /// Get current foreground app
  Future<String?> getCurrentForegroundApp() async {
    if (!Platform.isAndroid) return null;
    
    try {
      // Try native method first
      final result = await _channel.invokeMethod('getCurrentForegroundApp');
      if (result != null) return result;
      
      // Fallback to usage stats
      final endTime = DateTime.now();
      final startTime = endTime.subtract(const Duration(minutes: 1));
      
      final usageStats = await UsageStats.queryUsageStats(startTime, endTime);
      if (usageStats.isEmpty) return null;
      
      // Find the most recently used app
      UsageInfo? mostRecent;
      for (final usage in usageStats) {
        if (mostRecent == null || (usage.lastTimeUsed != null && mostRecent.lastTimeUsed != null && 
          DateTime.parse(usage.lastTimeUsed!).isAfter(DateTime.parse(mostRecent.lastTimeUsed!)))) {
          mostRecent = usage;
        }
      }
      
      return mostRecent?.packageName;
    } catch (e) {
      debugPrint('Error getting foreground app: $e');
      return null;
    }
  }

  /// Get app usage statistics for a specific period
  Future<List<UsageInfo>> getUsageStats(DateTime startTime, DateTime endTime) async {
    if (!Platform.isAndroid) return [];
    
    try {
      return await UsageStats.queryUsageStats(startTime, endTime);
    } catch (e) {
      debugPrint('Error getting usage stats: $e');
      return [];
    }
  }

  /// Get daily usage for a specific app
  Future<Duration> getDailyUsage(String packageName, DateTime date) async {
    final startTime = DateTime(date.year, date.month, date.day);
    final endTime = startTime.add(const Duration(days: 1));
    
    final usageStats = await getUsageStats(startTime, endTime);
    final appUsage = usageStats.where((usage) => usage.packageName == packageName);
    
    int totalTime = 0;
    for (final usage in appUsage) {
      totalTime += int.tryParse(usage.totalTimeInForeground ?? '0') ?? 0;
    }
    
    return Duration(milliseconds: totalTime);
  }

  /// Get app launch count for a specific period
  Future<int> getLaunchCount(String packageName, DateTime startTime, DateTime endTime) async {
    final usageStats = await getUsageStats(startTime, endTime);
    final appUsage = usageStats.where((usage) => usage.packageName == packageName);
    
    int totalLaunches = 0;
    for (final usage in appUsage) {
      final timeInForeground = int.tryParse(usage.totalTimeInForeground ?? '0') ?? 0;
      totalLaunches += timeInForeground > 0 ? 1 : 0;
    }
    
    return totalLaunches;
  }

  /// Check if usage access permission is granted
  Future<bool> hasUsagePermission() async {
    if (!Platform.isAndroid) return false;
    
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request usage access permission
  Future<void> requestUsagePermission() async {
    if (!Platform.isAndroid) return;
    
    try {
      await UsageStats.grantUsagePermission();
    } catch (e) {
      debugPrint('Error requesting usage permission: $e');
    }
  }

  /// Get most used apps in a time period
  Future<List<UsageInfo>> getMostUsedApps(DateTime startTime, DateTime endTime, {int limit = 10}) async {
    final usageStats = await getUsageStats(startTime, endTime);
    
    // Sort by total time in foreground
    usageStats.sort((a, b) {
      final aTime = int.tryParse(a.totalTimeInForeground ?? '0') ?? 0;
      final bTime = int.tryParse(b.totalTimeInForeground ?? '0') ?? 0;
      return bTime.compareTo(aTime);
    });
    
    return usageStats.take(limit).toList();
  }

  /// Dispose resources
  void dispose() {
    _monitoringTimer?.cancel();
    _appLaunchController.close();
    _foregroundAppController.close();
    stopMonitoring();
  }
}