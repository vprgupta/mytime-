import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_blocking/models/blocking_session.dart';
import '../../app_blocking/services/installed_apps_service.dart';
import 'package:installed_apps/app_info.dart';
import '../services/app_blocking_service_v2.dart';

class AppBlockingProviderV2 extends ChangeNotifier {
  final AppBlockingServiceV2 _service = AppBlockingServiceV2();
  final InstalledAppsService _appsService = InstalledAppsService();

  // State
  bool _isLoading = false;
  String? _error; // General error message
  List<String> _missingPermissions = []; // Specific missing permissions
  
  List<AppInfo> _installedApps = [];
  List<BlockingSession> _activeSessions = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<String> get missingPermissions => _missingPermissions;
  List<AppInfo> get installedApps => _installedApps;
  List<BlockingSession> get activeSessions => _activeSessions;
  
  bool get hasPermissionIssues => _missingPermissions.isNotEmpty;

  // Initialization
  Future<void> initialize() async {
    _setLoading(true);
    try {
      await _service.initialize();
      await _refreshPermissions();
      await _refreshSessions();
      
      // Load apps in background to prevent UI freeze
      _loadApps().then((_) {
        notifyListeners();
      });
    } catch (e) {
      _error = 'Failed to initialize: $e';
    } finally {
      _setLoading(false);
    }
  }

  // Actions
  Future<void> refreshData() async {
    await _refreshPermissions();
    await _refreshSessions();
    notifyListeners();
  }

  Future<void> blockApp(String packageName, int durationMinutes) async {
    try {
      _error = null;
      await _service.blockApp(packageName, durationMinutes);
      await _refreshSessions();
      notifyListeners();
    } on PlatformException catch (e) {
      if (e.code == 'MISSING_PERMISSIONS') {
        _missingPermissions = (e.details as List<dynamic>).cast<String>();
        notifyListeners();
      } else {
        _error = e.message;
        notifyListeners();
      }
    } catch (e) {
      _error = 'Failed to block app: $e';
      notifyListeners();
    }
  }

  Future<void> unblockApp(String packageName) async {
    try {
      await _service.unblockApp(packageName);
      await _refreshSessions();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to unblock app: $e';
      notifyListeners();
    }
  }

  // Helpers
  Future<void> _refreshPermissions() async {
    _missingPermissions = await _service.getMissingPermissions();
  }

  Future<void> _loadApps() async {
    _installedApps = await _appsService.getUserApps();
  }

  Future<void> _refreshSessions() async {
    _activeSessions = _service.getActiveSessions();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
  
  bool isAppBlocked(String packageName) {
    return _service.isAppBlocked(packageName);
  }
  
  Duration? getRemainingTime(String packageName) {
    final session = _activeSessions.firstWhere(
      (s) => s.appPackage == packageName, 
      orElse: () => BlockingSession(
        appPackage: '', 
        startTime: DateTime.now(), 
        endTime: DateTime.now(), 
        durationMinutes: 0, 
        createdAt: DateTime.now()
      )
    );
    
    if (session.appPackage.isNotEmpty) {
      return session.remainingTime;
    }
    return null;
  }

  // App Info Helper
  AppInfo? getAppInfo(String packageName) {
    try {
      return _installedApps.firstWhere((app) => app.packageName == packageName);
    } catch (e) {
      return null;
    }
  }

  // Uninstall Protection
  Future<void> setUninstallLock(int days) async {
    await _service.setUninstallLock(days);
    notifyListeners();
  }

  Future<Duration> getUninstallLockRemaining() async {
    return await _service.getUninstallLockRemaining();
  }
}
