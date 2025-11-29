import 'dart:typed_data';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

class InstalledAppsService {
  static final InstalledAppsService _instance = InstalledAppsService._internal();
  factory InstalledAppsService() => _instance;
  InstalledAppsService._internal();

  List<AppInfo> _cachedApps = [];
  DateTime? _lastCacheUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 30);

  /// Get all installed apps (excluding system apps by default)
  Future<List<AppInfo>> getInstalledApps({bool includeSystemApps = false}) async {
    if (_shouldRefreshCache()) {
      await _refreshCache(includeSystemApps);
    }
    return _cachedApps;
  }

  /// Get specific app info by package name
  Future<AppInfo?> getAppInfo(String packageName) async {
    try {
      final apps = await getInstalledApps();
      for (final app in apps) {
        if (app.packageName == packageName) {
          return app;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get app icon as bytes
  Future<Uint8List?> getAppIcon(String packageName) async {
    try {
      // First check cache
      final apps = await getInstalledApps();
      for (final app in apps) {
        if (app.packageName == packageName && app.icon != null) {
          return app.icon;
        }
      }
      
      // If not in cache, return null (fetching individually is problematic with current plugin version)
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Check if app is installed
  Future<bool> isAppInstalled(String packageName) async {
    try {
      final apps = await getInstalledApps();
      return apps.any((app) => app.packageName == packageName);
    } catch (e) {
      return false;
    }
  }

  /// Get user-installed apps (non-system apps)
  Future<List<AppInfo>> getUserApps() async {
    // We request system apps = false from the plugin first
    // This is the most efficient way if the plugin supports it correctly
    final apps = await getInstalledApps(includeSystemApps: false);
    
    // Double check with our manual filter just in case
    return apps.where((app) => !_isSystemApp(app)).toList();
  }

  /// Get popular social media and entertainment apps
  Future<List<AppInfo>> getPopularApps() async {
    final userApps = await getUserApps();
    final popularPackages = {
      'com.instagram.android',
      'com.facebook.katana',
      'com.twitter.android',
      'com.snapchat.android',
      'com.zhiliaoapp.musically', // TikTok
      'com.google.android.youtube',
      'com.netflix.mediaclient',
      'com.spotify.music',
      'com.whatsapp',
      'com.discord',
      'com.reddit.frontpage',
      'com.pinterest',
      'com.linkedin.android',
    };

    return userApps.where((app) => popularPackages.contains(app.packageName)).toList();
  }

  bool _shouldRefreshCache() {
    if (_lastCacheUpdate == null) return true;
    return DateTime.now().difference(_lastCacheUpdate!) > _cacheValidDuration;
  }

  Future<void> _refreshCache(bool includeSystemApps) async {
    try {
      // Fetch apps WITH icons to ensure we can display them
      _cachedApps = await InstalledApps.getInstalledApps(includeSystemApps, true);
      _lastCacheUpdate = DateTime.now();
    } catch (e) {
      // If installed_apps fails, return empty list
      _cachedApps = [];
      _lastCacheUpdate = DateTime.now();
    }
  }

  bool _isSystemApp(AppInfo app) {
    // Check if it's marked as system app
    // Check if it's marked as system app
    // Note: systemApp property not available in current AppInfo model
    
    // Additional checks for system apps
    final systemPackagePrefixes = [
      'com.android.',
      'com.google.android.',
      'android.',
      'com.samsung.',
      'com.sec.',
      'com.qualcomm.',
    ];
    
    return systemPackagePrefixes.any((prefix) => app.packageName.startsWith(prefix));
  }

  /// Clear cache to force refresh
  void clearCache() {
    _cachedApps.clear();
    _lastCacheUpdate = null;
  }
}