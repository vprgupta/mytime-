import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/app_usage_limit.dart';
import 'app_blocking_service_v2.dart';

class AppUsageLimiterService {
  static final AppUsageLimiterService _instance = AppUsageLimiterService._internal();
  factory AppUsageLimiterService() => _instance;
  AppUsageLimiterService._internal();

  late Box<AppUsageLimit> _limitsBox;
  late Box<Map> _durationsBox;
  final Map<String, Timer> _usageTimers = {};
  final Map<String, DateTime> _appStartTimes = {};
  bool _isInitialized = false;

  static const platform = MethodChannel('app_blocking');
  static const String _limitsBoxName = 'app_usage_limits';
  static const String _durationsBoxName = 'usage_limit_durations';

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Ensure adapter is registered
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(AppUsageLimitAdapter());
    }

    // Open limits box with migration handling
    try {
      if (!Hive.isBoxOpen(_limitsBoxName)) {
        _limitsBox = await Hive.openBox<AppUsageLimit>(_limitsBoxName);
      } else {
        _limitsBox = Hive.box<AppUsageLimit>(_limitsBoxName);
      }
    } catch (e) {
      // If there's a type mismatch, delete and recreate the box
      debugPrint('Migration needed: Clearing old limits box due to structure change');
      await Hive.deleteBoxFromDisk(_limitsBoxName);
      _limitsBox = await Hive.openBox<AppUsageLimit>(_limitsBoxName);
    }
    
    // Open durations box
    try {
      if (!Hive.isBoxOpen(_durationsBoxName)) {
        _durationsBox = await Hive.openBox<Map>(_durationsBoxName);
      } else {
        _durationsBox = Hive.box<Map>(_durationsBoxName);
      }
    } catch (e) {
      debugPrint('Migration needed: Clearing old durations box');
      await Hive.deleteBoxFromDisk(_durationsBoxName);
      _durationsBox = await Hive.openBox<Map>(_durationsBoxName);
    }

    await _performDailyReset();
    
    // RE-SYNC: Notify native about all active limits
    // This ensures tracking works after app restart/reinstall
    try {
      final activeLimits = _limitsBox.values.where((l) => l.isActive).toList();
      for (var limit in activeLimits) {
        await _notifyNativeLimitAdded(
          limit.packageName,
          limit.currentLimitMinutes,
          limit.usedMinutesToday,
        );
        debugPrint('🔄 Re-synced limit: ${limit.appName}');
      }
      if (activeLimits.isNotEmpty) {
        debugPrint('✅ Re-synced ${activeLimits.length} limits with native');
      }
    } catch (e) {
      debugPrint('Error re-syncing limits: $e');
    }
    
    _isInitialized = true;
    
    // Setup MethodChannel listener
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onLimitedAppLaunched') {
        final packageName = call.arguments['packageName'] as String?;
        if (packageName != null) {
          debugPrint('🚀 Native reported limited app launch: $packageName');
          // We don't need to start timer here anymore as native handles it, 
          // but we can keep it for UI updates if needed.
          // startAppUsage(packageName); 
        }
      } else if (call.method == 'onLimitedAppClosed') {
        final packageName = call.arguments['packageName'] as String?;
        if (packageName != null) {
          debugPrint('⏹️ Native reported limited app closed: $packageName');
          // stopAppUsage(packageName);
        }
      } else if (call.method == 'updateUsage') {
        final packageName = call.arguments['packageName'] as String?;
        final usedMinutes = call.arguments['usedMinutes'] as int?;
        
        if (packageName != null && usedMinutes != null) {
          debugPrint('🔄 Native updated usage for $packageName: $usedMinutes minutes');
          await _syncUsageFromNative(packageName, usedMinutes);
        }
      }
    });

    // Sync all active limits to native on startup
    for (var limit in _limitsBox.values) {
      if (limit.isActive && !limit.isBlocked) {
        await _notifyNativeLimitAdded(limit.packageName, limit.currentLimitMinutes, limit.usedMinutesToday);
      }
    }

    _isInitialized = true;
  }

  // Set a usage limit for an app
  Future<void> setAppLimit(String packageName, String appName, int limitMinutes, {int durationDays = -1, bool hasCommitment = false}) async {
    await initialize();
    
    final now = DateTime.now();
    final existingLimit = await getAppLimit(packageName);
    
    int currentUsed = 0;
    
    if (existingLimit != null) {
      currentUsed = existingLimit.usedMinutesToday;
      // Update existing limit
      if (existingLimit.isInBox) {
        await existingLimit.delete();
      }
      
      final updatedLimit = existingLimit.copyWith(
        initialLimitMinutes: limitMinutes,
        currentLimitMinutes: limitMinutes,
        hasCommitment: hasCommitment,
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
        hasCommitment: hasCommitment,
        lastResetDate: now,
        createdAt: now,
        updatedAt: now,
      );
      
      await _limitsBox.add(newLimit);
    }
    
    // Store duration info
    if (durationDays != -1) {
      await _durationsBox.put(packageName, {
        'durationDays': durationDays,
        'startDate': now.toIso8601String(),
        'hasCommitment': hasCommitment,
      });
    } else {
      // If indefinite, remove any existing duration info
      await _durationsBox.delete(packageName);
    }
    
    // Notify native side that this app now has a limit (for AccessibilityService tracking)
    await _notifyNativeLimitAdded(packageName, limitMinutes, currentUsed);
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

  // Sync usage from native
  Future<void> _syncUsageFromNative(String packageName, int usedMinutes) async {
    final limit = await getAppLimit(packageName);
    if (limit == null) return;
    
    // Only update if native usage is greater (to avoid race conditions)
    if (usedMinutes > limit.usedMinutesToday) {
       if (limit.isInBox) {
        await limit.delete();
      }
      
      final updatedLimit = limit.copyWith(
        usedMinutesToday: usedMinutes,
        updatedAt: DateTime.now(),
      );
      
      await _limitsBox.add(updatedLimit);
      
      // Check if limit is exceeded (Native should have blocked it, but we update UI state)
      if (updatedLimit.isLimitExceeded && !updatedLimit.isBlocked) {
        await _blockAppForToday(packageName);
      }
    }
  }

  Future<void> _notifyNativeLimitAdded(String packageName, int limitMinutes, int usedMinutes) async {
    try {
      await platform.invokeMethod('setAppLimit', {
        'packageName': packageName,
        'limitMinutes': limitMinutes,
        'usedMinutes': usedMinutes
      });
      debugPrint('📊 Notified native: Limit set for $packageName ($usedMinutes/$limitMinutes)');
    } catch (e) {
      debugPrint('Error notifying native about limit: $e');
    }
  }

  Future<void> _notifyNativeLimitRemoved(String packageName) async {
    try {
      await platform.invokeMethod('removeLimitedApp', {'packageName': packageName});
      debugPrint('📊 Notified native: Limit removed for $packageName');
    } catch (e) {
      debugPrint('Error notifying native about limit removal: $e');
    }
  }

  // Perform daily reset - called at app startup
  Future<void> _performDailyReset() async {
    final now = DateTime.now();
    final limitsToUpdate = <AppUsageLimit>[];
    final limitsToRemove = <AppUsageLimit>[];
    
    for (var limit in _limitsBox.values) {
      // Check for expiration
      final durationInfo = _durationsBox.get(limit.packageName);
      bool isExpired = false;
      
      if (durationInfo != null) {
        final durationDays = durationInfo['durationDays'] as int;
        final startDateStr = durationInfo['startDate'] as String;
        final startDate = DateTime.parse(startDateStr);
        final expiryDate = startDate.add(Duration(days: durationDays));
        
        if (now.isAfter(expiryDate)) {
          isExpired = true;
        }
      }
      
      if (isExpired) {
        limitsToRemove.add(limit);
      } else if (limit.shouldResetToday) {
        limitsToUpdate.add(limit);
      }
    }
    
    // Remove expired limits
    for (var limit in limitsToRemove) {
      await removeAppLimit(limit.packageName);
      debugPrint('Limit expired for ${limit.packageName}');
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
      // Check if limit has commitment mode enabled
      if (limit.hasCommitment) {
        // Check if commitment period is still active
        final durationInfo = _durationsBox.get(packageName);
        if (durationInfo != null) {
          final hasCommitment = durationInfo['hasCommitment'] as bool? ?? false;
          if (hasCommitment) {
            final durationDays = durationInfo['durationDays'] as int;
            final startDateStr = durationInfo['startDate'] as String;
            final startDate = DateTime.parse(startDateStr);
            final expiryDate = startDate.add(Duration(days: durationDays));
            final now = DateTime.now();
            
            if (now.isBefore(expiryDate)) {
              final remainingDays = expiryDate.difference(now).inDays + 1;
              throw Exception('Cannot remove limit: Commitment mode is active for $remainingDays more day${remainingDays == 1 ? "" : "s"}');
            }
          }
        } else if (limit.hasCommitment) {
          // Indefinite commitment
          throw Exception('Cannot remove limit: Commitment mode is active indefinitely');
        }
      }
      
      if (limit.isInBox) {
        await limit.delete();
      }
      
      // Remove duration info
      if (_durationsBox.containsKey(packageName)) {
        await _durationsBox.delete(packageName);
      }
      
      final deactivatedLimit = limit.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
      );
      
      await _limitsBox.add(deactivatedLimit);
      
      // Stop any active tracking
      await stopAppUsage(packageName);
      
      // Notify native side to stop watching
      await _notifyNativeLimitRemoved(packageName);
      
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