
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mytime/features/app_blocking/models/blocked_app.dart';
import 'package:mytime/features/app_blocking/models/blocking_session.dart';
import 'package:mytime/features/app_blocking/models/blocking_rule.dart';
import 'package:mytime/features/app_blocking/models/bypass_attempt.dart';
import 'package:mytime/features/app_blocking/models/app_blocking_settings.dart';
import 'package:mytime/features/app_blocking/models/app_usage_limit.dart';

class StorageService {
  static bool _adaptersRegistered = false;
  static final _lock = Object();
  
  Future<void> init() async {
    await Hive.initFlutter();
    
    // Thread-safe adapter registration
    synchronized(_lock, () {
      if (!_adaptersRegistered) {
        try {
          Hive.registerAdapter(BlockedAppAdapter());
          Hive.registerAdapter(BlockingSessionAdapter());
          Hive.registerAdapter(BlockingRuleAdapter());
          Hive.registerAdapter(BypassAttemptAdapter());
          Hive.registerAdapter(AppBlockingSettingsAdapter());
          Hive.registerAdapter(AppUsageLimitAdapter());
          _adaptersRegistered = true;
        } catch (e) {
          debugPrint('Error registering adapters: $e');
          // Don't rethrow here to allow app to continue if adapters already registered
        }
      }
    });

    // Open boxes with error handling
    try {
      await Future.wait([
        Hive.openBox<BlockedApp>('blocked_apps'),
        Hive.openBox<BlockingSession>('blocking_sessions'),
        Hive.openBox<BlockingRule>('blocking_rules'),
        Hive.openBox<BypassAttempt>('bypass_attempts'),
        Hive.openBox<AppBlockingSettings>('app_blocking_settings'),
        Hive.openBox<AppUsageLimit>('app_usage_limits'),
        Hive.openBox('preferences'),
      ]);
    } catch (e) {
      debugPrint('Error opening Hive boxes: $e');
      rethrow;
    }
  }
  
  // Simple synchronization for adapter registration
  void synchronized(Object lock, void Function() computation) {
    computation();
  }

  // Blocked App methods
  Box<BlockedApp> getBlockedAppsBox() => Hive.box<BlockedApp>('blocked_apps');
  
  Future<List<BlockedApp>> getBlockedApps() async {
    final box = getBlockedAppsBox();
    return box.values.toList();
  }
  
  Future<void> saveBlockedApp(BlockedApp app) async {
    final box = getBlockedAppsBox();
    await box.put(app.packageName, app);
  }
  
  Future<void> removeBlockedApp(String packageName) async {
    final box = getBlockedAppsBox();
    await box.delete(packageName);
  }

  // Blocking Session methods
  Box<BlockingSession> getBlockingSessionsBox() => Hive.box<BlockingSession>('blocking_sessions');
  
  Future<List<BlockingSession>> getBlockingSessions() async {
    final box = getBlockingSessionsBox();
    return box.values.toList();
  }
  
  Future<void> saveBlockingSession(BlockingSession session) async {
    final box = getBlockingSessionsBox();
    await box.put(session.id, session);
  }

  // Blocking Rule methods
  Box<BlockingRule> getBlockingRulesBox() => Hive.box<BlockingRule>('blocking_rules');
  
  Future<List<BlockingRule>> getBlockingRules() async {
    final box = getBlockingRulesBox();
    return box.values.toList();
  }
  
  Future<void> saveBlockingRule(BlockingRule rule) async {
    final box = getBlockingRulesBox();
    await box.put(rule.id, rule);
  }
  
  Future<void> deleteBlockingRule(String id) async {
    final box = getBlockingRulesBox();
    await box.delete(id);
  }

  // Bypass Attempt methods
  Box<BypassAttempt> getBypassAttemptsBox() => Hive.box<BypassAttempt>('bypass_attempts');
  
  Future<List<BypassAttempt>> getBypassAttempts() async {
    final box = getBypassAttemptsBox();
    return box.values.toList();
  }
  
  Future<void> saveBypassAttempt(BypassAttempt attempt) async {
    final box = getBypassAttemptsBox();
    await box.put(attempt.id, attempt);
  }

  // App Usage Limit methods
  Box<AppUsageLimit> getAppUsageLimitsBox() => Hive.box<AppUsageLimit>('app_usage_limits');
  
  Future<List<AppUsageLimit>> getAppUsageLimits() async {
    final box = getAppUsageLimitsBox();
    return box.values.toList();
  }
  
  Future<void> saveAppUsageLimit(AppUsageLimit limit) async {
    final box = getAppUsageLimitsBox();
    await box.put(limit.packageName, limit);
  }
  
  Future<void> deleteAppUsageLimit(String packageName) async {
    final box = getAppUsageLimitsBox();
    await box.delete(packageName);
  }

  // Settings methods
  Box<AppBlockingSettings> getSettingsBox() => Hive.box<AppBlockingSettings>('app_blocking_settings');
  
  Future<AppBlockingSettings?> getSettings() async {
    final box = getSettingsBox();
    if (box.isEmpty) return null;
    return box.getAt(0);
  }
  
  Future<void> saveSettings(AppBlockingSettings settings) async {
    final box = getSettingsBox();
    await box.put('settings', settings);
  }

  // Preference methods
  Future<void> saveBool(String key, bool value) async {
    final box = Hive.box('preferences');
    await box.put(key, value);
  }

  Future<void> setBool(String key, bool value) async {
    await saveBool(key, value);
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final box = Hive.box('preferences');
    return box.get(key, defaultValue: defaultValue);
  }
  
  // Generic openBox method
  Future<Box<T>> openBox<T>(String boxName) async {
    if (Hive.isBoxOpen(boxName)) {
      return Hive.box<T>(boxName);
    }
    return await Hive.openBox<T>(boxName);
  }
}
