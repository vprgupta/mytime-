import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/app_usage_limit.dart';
import 'app_blocking_service_v2.dart';

class AppUsageLimiterService {
  static final AppUsageLimiterService _instance = AppUsageLimiterService._internal();
  factory AppUsageLimiterService() => _instance;
  AppUsageLimiterService._internal();

  late Box<AppUsageLimit> _limitsBox;
  final Map<String, Timer> _usageTimers = {};
  final Map<String, DateTime> _appStartTimes = {};
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _limitsBox = await Hive.openBox<AppUsageLimit>('app_usage_limits');
    await _performDailyReset();
    _isInitialized = true;
  }

  // Set a usage limit for an app
  Future<void> setAppLimit(String packageName, String appName, int limitMinutes) async {
    await initialize();
    
    final now = DateTime.now();
    final existingLimit = await getAppLimit(packageName);
    
    if (existingLimit != null) {
      // Update existing limit
      if (existingLimit.isInBox) {
        await existingLimit.delete();
      }
      
      final updatedLimit = existingLimit.copyWith(
        initialLimitMinutes: limitMinutes,
        currentLimitMinutes: limitMinutes,
        updatedAt: now,
      );
      
      await _limitsBox.add(updatedLimit);
    } else {
      // Create new limit
      final newLimit = AppUsageLimit(
        packageName: packageName,
        appName: appName,
        initialLimitMinutes: limitMinutes,
        currentLimitMinutes: limitMinutes,
        lastResetDate: now,
        createdAt: now,
        updatedAt: now,
      );
      
      await _limitsBox.add(newLimit);
    }
    
    // Notify native side that this app now has a limit (for AccessibilityService tracking)
    await _notifyNativeLimitAdded(packageName);
  }
  
  Future<void> _notifyNativeLimitAdded(String packageName) async {
    try {
      // This would call a native method to add the package to limited apps
      // We'll need to add this method to MainActivity
      debugPrint('📊 Notified native: Limit added for $packageName');
    } catch (e) {
      debugPrint('Error notifying native about limit: $e');
    }
  }

  // Get usage limit for an app
  Future<AppUsageLimit?> getAppLimit(String packageName) async {
    await initialize();
    
    for (var limit in _limitsBox.values) {
      if (limit.packageName == packageName && limit.isActive) {
        return limit;
      }
    }
    return null;
  }

  // Start tracking usage when app is opened
  Future<void> startAppUsage(String packageName) async {
    await initialize();
    
    final limit = await getAppLimit(packageName);
    if (limit == null || limit.isBlocked) return;
    
    _appStartTimes[packageName] = DateTime.now();
    
    // Start a timer to track usage
    _usageTimers[packageName] = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _incrementUsage(packageName);
    });
  }

  // Stop tracking usage when app is closed
  Future<void> stopAppUsage(String packageName) async {
    await initialize();
    
    // Cancel timer
    _usageTimers[packageName]?.cancel();
    _usageTimers.remove(packageName);
    
    // Calculate final usage if app was being tracked
    if (_appStartTimes.containsKey(packageName)) {
      final startTime = _appStartTimes[packageName]!;
      final endTime = DateTime.now();
      final usageMinutes = endTime.difference(startTime).inMinutes;
      
      if (usageMinutes > 0) {
        await _addUsage(packageName, usageMinutes);
      }
      
      _appStartTimes.remove(packageName);
    }
  }

  // Increment usage by 1 minute
  Future<void> _incrementUsage(String packageName) async {
    await _addUsage(packageName, 1);
  }

  // Add usage minutes to an app
  Future<void> _addUsage(String packageName, int minutes) async {
    final limit = await getAppLimit(packageName);
    if (limit == null) return;
    
    final newUsage = limit.usedMinutesToday + minutes;
    final now = DateTime.now();
    
    // Update the limit
    if (limit.isInBox) {
      await limit.delete();
    }
    
    final updatedLimit = limit.copyWith(
      usedMinutesToday: newUsage,
      updatedAt: now,
    );
    
    await _limitsBox.add(updatedLimit);
    
    // Check if limit is exceeded
    if (updatedLimit.isLimitExceeded && !updatedLimit.isBlocked) {
      await _blockAppForToday(packageName);
    }
  }

  // Block app for the rest of the day
  Future<void> _blockAppForToday(String packageName) async {
    final limit = await getAppLimit(packageName);
    if (limit == null) return;
    
    // Update limit to blocked state
    if (limit.isInBox) {
      await limit.delete();
    }
    
    final blockedLimit = limit.copyWith(
      isBlocked: true,
      updatedAt: DateTime.now(),
    );
    
    await _limitsBox.add(blockedLimit);
    
    // Stop any active usage tracking
    await stopAppUsage(packageName);
    
    // Start blocking session for the rest of the day
    final now = DateTime.now();
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);
    final remainingMinutes = endOfDay.difference(now).inMinutes;
    
    if (remainingMinutes > 0) {
      try {
        await AppBlockingServiceV2().blockApp(packageName, remainingMinutes);
        debugPrint('App $packageName blocked for exceeding daily limit');
      } catch (e) {
        debugPrint('Error blocking app after limit exceeded: $e');
      }
    }
  }

  // Perform daily reset - called at app startup
  Future<void> _performDailyReset() async {
    final now = DateTime.now();
    final limitsToUpdate = <AppUsageLimit>[];
    
    for (var limit in _limitsBox.values) {
      if (limit.shouldResetToday) {
        limitsToUpdate.add(limit);
      }
    }
    
    for (var limit in limitsToUpdate) {
      if (limit.isInBox) {
        await limit.delete();
      }
      
      // Calculate new daily limit (reduce by 1 minute each day)
      final newDayCount = limit.consecutiveDays + 1;
      final newLimit = (limit.initialLimitMinutes - newDayCount).clamp(1, limit.initialLimitMinutes);
      
      final resetLimit = limit.copyWith(
        currentLimitMinutes: newLimit,
        usedMinutesToday: 0,
        lastResetDate: now,
        isBlocked: false,
        consecutiveDays: newDayCount,
        updatedAt: now,
      );
      
      await _limitsBox.add(resetLimit);
      
      // If app was blocked, unblock it for the new day
      if (limit.isBlocked) {
        try {
          await AppBlockingServiceV2().unblockApp(limit.packageName);
        } catch (e) {
          debugPrint('Error unblocking app during daily reset: $e');
        }
      }
    }
  }

  // Get all active limits
  List<AppUsageLimit> getAllLimits() {
    return _limitsBox.values.where((limit) => limit.isActive).toList();
  }

  // Remove limit for an app
  Future<void> removeAppLimit(String packageName) async {
    await initialize();
    
    final limit = await getAppLimit(packageName);
    if (limit != null) {
      if (limit.isInBox) {
        await limit.delete();
      }
      
      final deactivatedLimit = limit.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
      );
      
      await _limitsBox.add(deactivatedLimit);
      
      // Stop any active tracking
      await stopAppUsage(packageName);
      
      // Unblock if currently blocked
      if (limit.isBlocked) {
        try {
          await AppBlockingServiceV2().unblockApp(packageName);
        } catch (e) {
          debugPrint('Error unblocking app when removing limit: $e');
        }
      }
    }
  }

  // Check if app is currently limited
  Future<bool> isAppLimited(String packageName) async {
    final limit = await getAppLimit(packageName);
    return limit != null && limit.isActive;
  }

  // Check if app is blocked due to limit
  Future<bool> isAppBlockedByLimit(String packageName) async {
    final limit = await getAppLimit(packageName);
    return limit != null && limit.isBlocked;
  }

  // Get remaining time for an app today
  Future<int> getRemainingMinutes(String packageName) async {
    final limit = await getAppLimit(packageName);
    return limit?.remainingMinutes ?? 0;
  }

  // Get usage statistics for an app
  Future<Map<String, dynamic>> getAppUsageStats(String packageName) async {
    final limit = await getAppLimit(packageName);
    if (limit == null) {
      return {
        'hasLimit': false,
      };
    }
    
    return {
      'hasLimit': true,
      'initialLimit': limit.initialLimitMinutes,
      'currentLimit': limit.currentLimitMinutes,
      'usedToday': limit.usedMinutesToday,
      'remainingToday': limit.remainingMinutes,
      'isBlocked': limit.isBlocked,
      'consecutiveDays': limit.consecutiveDays,
      'progressPercentage': (limit.usedMinutesToday / limit.currentLimitMinutes * 100).clamp(0, 100),
    };
  }

  // Force daily reset (for testing or manual trigger)
  Future<void> forceDailyReset() async {
    await _performDailyReset();
  }

  void dispose() {
    // Cancel all active timers
    for (var timer in _usageTimers.values) {
      timer.cancel();
    }
    _usageTimers.clear();
    _appStartTimes.clear();
  }
}