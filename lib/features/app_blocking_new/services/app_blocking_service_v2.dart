import 'dart:async';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../../app_blocking/models/blocking_session.dart';
import '../../app_blocking/services/app_usage_limiter_service.dart';
import '../models/app_schedule.dart';

class AppBlockingServiceV2 {
  static final AppBlockingServiceV2 _instance = AppBlockingServiceV2._internal();
  factory AppBlockingServiceV2() => _instance;
  AppBlockingServiceV2._internal();

  static const MethodChannel _channel = MethodChannel('app_blocking');
  

  late Box<BlockingSession> _sessionsBox;
  bool _isInitialized = false;

  Timer? _sessionCheckTimer;
  
  final _sessionsChangedController = StreamController<void>.broadcast();
  Stream<void> get onSessionsChanged => _sessionsChangedController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {

      _sessionsBox = await Hive.openBox<BlockingSession>('blocking_sessions_v2');
      await _initSchedules();
      _isInitialized = true;
      
      // Start monitoring for expired sessions
      _startSessionExpirationCheck();
      
      // Sync active sessions to native side (Persistence)
      await _syncActiveSessionsToNative();
      
      // Set up callback handler for usage limiter events
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onLimitedAppLaunched':
            final packageName = call.arguments['packageName'] as String?;
            if (packageName != null) {
              await _handleAppLaunched(packageName);
            }
            break;
          case 'onLimitedAppClosed':
            final packageName = call.arguments['packageName'] as String?;
            if (packageName != null) {
              await _handleAppClosed(packageName);
            }
            break;
        }
      });
    } catch (e) {
      // debugPrint('Error initializing AppBlockingServiceV2: $e');
    }
  }
  
  Future<void> _handleAppLaunched(String packageName) async {
    // Forward to limiter service
    try {
      final limiterService = AppUsageLimiterService();
      await limiterService.startAppUsage(packageName);
      // debugPrint('📊 Started tracking usage for: $packageName');
    } catch (e) {
      // debugPrint('Error starting usage tracking: $e');
    }
  }
  
  Future<void> _handleAppClosed(String packageName) async {
    // Forward to limiter service
    try {
      final limiterService = AppUsageLimiterService();
      await limiterService.stopAppUsage(packageName);
      // debugPrint('📊 Stopped tracking usage for: $packageName');
    } catch (e) {
      // debugPrint('Error stopping usage tracking: $e');
    }
  }

  Future<void> _syncActiveSessionsToNative() async {
    try {
      final activeSessions = getActiveSessions();
      for (var session in activeSessions) {
        await _channel.invokeMethod('addBlockedApp', {'packageName': session.appPackage});
      }
      if (activeSessions.isNotEmpty) {
        await _channel.invokeMethod('startMonitoring');
      }
    } catch (e) {
      // debugPrint('Error syncing sessions to native: $e');
    }
  }

  /// Check if all required permissions are granted
  Future<bool> hasAllPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      if (result is Map) {
        // Device Admin is optional - only needed for uninstall prevention
        return result['usageStats'] == true && 
               result['accessibility'] == true && 
               result['overlay'] == true;
      }
      return false;
    } catch (e) {
      // debugPrint('Error checking permissions: $e');
      return false;
    }
  }

  /// Get list of missing permissions for UI feedback
  Future<List<String>> getMissingPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      final missing = <String>[];
      
      if (result is Map) {
        if (result['usageStats'] != true) missing.add('Usage Access');
        if (result['accessibility'] != true) missing.add('Accessibility Service');
        if (result['overlay'] != true) missing.add('Display over other apps');
        // Device Admin is optional - not in the critical missing list
      }
      return missing;
    } catch (e) {
      return ['Unable to check permissions'];
    }
  }

  /// Start blocking a specific app
  Future<void> blockApp(String packageName, int durationMinutes) async {
    if (!_isInitialized) await initialize();

    // 1. Validate Input
    if (packageName.isEmpty || durationMinutes <= 0) {
      throw Exception('Invalid parameters');
    }

    // 2. Check Permissions (Fail fast but safely)
    if (!await hasAllPermissions()) {
      final missing = await getMissingPermissions();
      throw PlatformException(
        code: 'MISSING_PERMISSIONS',
        message: 'Missing: ${missing.join(", ")}',
        details: missing
      );
    }

    // 3. Create Session
    final now = DateTime.now();
    final endTime = now.add(Duration(minutes: durationMinutes));
    
    final session = BlockingSession(
      appPackage: packageName,
      startTime: now,
      endTime: endTime,
      durationMinutes: durationMinutes,
      createdAt: now,
    );

    // 4. Save to Local Storage
    await _sessionsBox.add(session);
    
    // 5. Enforce Native Block (with endTime for persistence)
    try {
      await _channel.invokeMethod('addBlockedApp', {
        'packageName': packageName,
        'endTime': endTime.millisecondsSinceEpoch,  // Pass endTime for persistence!
      });
      await _channel.invokeMethod('startMonitoring');
    } catch (e) {
      // If native call fails, we should probably rollback the session or mark it as failed
      // debugPrint('Native block failed: $e');
      throw Exception('Failed to enforce block on device');
    }
    
    _sessionsChangedController.add(null);
  }

  /// Stop blocking an app
  Future<void> unblockApp(String packageName) async {
    if (!_isInitialized) await initialize();

    // Remove from local storage (mark as completed)
    final sessions = _sessionsBox.values.where((s) => s.appPackage == packageName && s.isActive);
    for (var session in sessions) {
      if (session.isInBox) await session.delete();
    }

    // Remove from native
    try {
      await _channel.invokeMethod('removeBlockedApp', {'packageName': packageName});
    } catch (e) {
      // debugPrint('Error unblocking app natively: $e');
    }
    
    _sessionsChangedController.add(null);
  }

  /// Get currently active sessions
  List<BlockingSession> getActiveSessions() {
    if (!_isInitialized) return [];
    return _sessionsBox.values.where((s) => s.isActive && !s.isExpired).toList();
  }

  /// Check if an app is currently blocked
  bool isAppBlocked(String packageName) {
    if (!_isInitialized) return false;
    return _sessionsBox.values.any((s) => s.appPackage == packageName && s.isActive && !s.isExpired);
  }

  // --- Session Expiration Logic ---

  void _startSessionExpirationCheck() {
    _sessionCheckTimer?.cancel();
    _sessionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkAndExpireSessions();
    });
  }

  void _checkAndExpireSessions() {
    if (!_isInitialized) return;

    final expiredSessions = <String>[];
    
    // Find expired sessions
    for (var session in _sessionsBox.values) {
      if (session.isActive && session.isExpired) {
        expiredSessions.add(session.appPackage);
      }
    }
    
    // Process expirations
    for (var packageName in expiredSessions) {
      // debugPrint('Auto-expiring session for $packageName');
      unblockApp(packageName);
    }
    
    if (expiredSessions.isNotEmpty) {
      _sessionsChangedController.add(null);
    }
  }

  void dispose() {
    _sessionCheckTimer?.cancel();
  }

  // Uninstall Protection Methods
  
  Future<void> enableDeviceAdmin() async {
    try {
      await _channel.invokeMethod('enableDeviceAdmin');
    } catch (e) {
      // debugPrint('Error enabling device admin: $e');
    }
  }

  Future<void> setUninstallLock(int days) async {
    final endTime = DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch;
    try {
      await _channel.invokeMethod('setUninstallLock', {'timestamp': endTime});
      // Also ensure device admin is enabled
      await enableDeviceAdmin();
    } catch (e) {
      // debugPrint('Error setting uninstall lock: $e');
    }
  }

  Future<Duration> getUninstallLockRemaining() async {
    try {
      final timestamp = await _channel.invokeMethod<int>('getUninstallLock') ?? 0;
      if (timestamp == 0) return Duration.zero;
      
      final endTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      if (endTime.isAfter(now)) {
        return endTime.difference(now);
      }
      return Duration.zero;
    } catch (e) {
      return Duration.zero;
    }
    }


  // --- Block Scheduler ---

  late Box<AppSchedule> _schedulesBox;

  Future<void> _initSchedules() async {
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(AppScheduleAdapter());
    }
    _schedulesBox = await Hive.openBox<AppSchedule>('app_schedules');
  }

  List<AppSchedule> getSchedules() {
    if (!_isInitialized) return [];
    return _schedulesBox.values.toList();
  }

  Future<void> saveSchedule(AppSchedule schedule) async {
    if (!_isInitialized) await initialize();
    if (!_schedulesBox.isOpen) await _initSchedules();

    // COMMITMENT MODE CHECK
    final existing = _schedulesBox.get(schedule.packageName);
    if (existing != null) {
       try {
         final result = await _channel.invokeMethod('getCommitmentStatus');
         if (result is Map && result['isActive'] == true) {
            throw Exception('Cannot modify schedules while Commitment Mode is active.');
         }
       } catch (e) {
         // Ignore
       }
    }

    await _schedulesBox.put(schedule.packageName, schedule);
    
    // Sync to Native
    await _syncScheduleToNative(schedule);
    _sessionsChangedController.add(null);
  }

  Future<void> deleteSchedule(String packageName) async {
    if (!_isInitialized) await initialize();
    if (!_schedulesBox.isOpen) await _initSchedules();

    // COMMITMENT MODE CHECK
    try {
       final result = await _channel.invokeMethod('getCommitmentStatus');
       if (result is Map && result['isActive'] == true) {
          throw Exception('Cannot delete schedules while Commitment Mode is active.');
       }
    } catch (e) {}

    await _schedulesBox.delete(packageName);
    
    // Sync to Native (Remove)
    await _channel.invokeMethod('removeAppSchedule', {'packageName': packageName});
    _sessionsChangedController.add(null);
  }

  Future<void> _syncScheduleToNative(AppSchedule schedule) async {
    await _channel.invokeMethod('setAppSchedule', {
      'packageName': schedule.packageName,
      'startHour': schedule.startHour,
      'startMinute': schedule.startMinute,
      'endHour': schedule.endHour,
      'endMinute': schedule.endMinute,
      'isEnabled': schedule.isEnabled,
    });
  }
}

