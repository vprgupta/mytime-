import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class DeviceAdminService {
  static final DeviceAdminService _instance = DeviceAdminService._internal();
  factory DeviceAdminService() => _instance;
  DeviceAdminService._internal();

  static const MethodChannel _channel = MethodChannel('app_blocking');
  
  bool _hasDeviceAdmin = false;
  bool _hasUsageAccess = false;
  bool _hasAccessibilityService = false;
  bool _hasOverlayPermission = false;

  /// Initialize and check all permissions
  Future<void> initialize() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _checkAllPermissions();
    } catch (e) {
      debugPrint('Error initializing device admin service: $e');
      // Set default values on error
      _hasDeviceAdmin = false;
      _hasUsageAccess = false;
      _hasAccessibilityService = false;
      _hasOverlayPermission = false;
    }
  }

  /// Request Device Admin permission specifically
  Future<bool> requestDeviceAdmin() async {
    if (!Platform.isAndroid) return false;
    
    try {
      await _channel.invokeMethod('enableDeviceAdmin');
      await Future.delayed(const Duration(seconds: 1));
      await _checkAllPermissions();
      return _hasDeviceAdmin;
    } catch (e) {
      debugPrint('Error requesting device admin: $e');
      return false;
    }
  }

  /// Request Usage Access Settings permission specifically
  Future<bool> requestUsageAccess() async {
    if (!Platform.isAndroid) return false;
    
    try {
      await _channel.invokeMethod('requestUsageStats');
      await Future.delayed(const Duration(seconds: 1));
      await _checkAllPermissions();
      return _hasUsageAccess;
    } catch (e) {
      debugPrint('Error requesting usage access: $e');
      return false;
    }
  }

  /// Request Accessibility Service permission specifically
  Future<bool> requestAccessibilityService() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // Show warning dialog before opening accessibility settings
      await _showAccessibilityWarning();
      await _channel.invokeMethod('openAccessibilitySettings');
      await Future.delayed(const Duration(seconds: 2));
      await _checkAllPermissions();
      return _hasAccessibilityService;
    } catch (e) {
      debugPrint('Error requesting accessibility service: $e');
      return false;
    }
  }
  
  /// Show warning about accessibility service
  Future<void> _showAccessibilityWarning() async {
    // This would be implemented in the UI layer
    debugPrint('WARNING: Enable accessibility service carefully. If your device freezes, restart it.');
  }

  /// Request System Alert Window permission (for overlays) specifically
  Future<bool> requestOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    
    try {
      await _channel.invokeMethod('requestOverlay');
      await Future.delayed(const Duration(seconds: 1));
      await _checkAllPermissions();
      return _hasOverlayPermission;
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
      return false;
    }
  }

  /// Check permissions using the existing MainActivity methods
  Future<bool> hasDeviceAdmin() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      if (result is Map) {
        _hasDeviceAdmin = result['deviceAdmin'] ?? false;
        return _hasDeviceAdmin;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if usage access is granted
  Future<bool> hasUsageAccess() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      if (result is Map) {
        _hasUsageAccess = result['usageStats'] ?? false;
        return _hasUsageAccess;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if accessibility service is enabled
  Future<bool> hasAccessibilityService() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      if (result is Map) {
        _hasAccessibilityService = result['accessibility'] ?? false;
        return _hasAccessibilityService;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if overlay permission is granted
  Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      if (result is Map) {
        _hasOverlayPermission = result['overlay'] ?? false;
        return _hasOverlayPermission;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check all permissions at once
  Future<void> _checkAllPermissions() async {
    try {
      await Future.wait([
        hasDeviceAdmin().catchError((e) => false),
        hasUsageAccess().catchError((e) => false),
        hasAccessibilityService().catchError((e) => false),
        hasOverlayPermission().catchError((e) => false),
      ]);
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  /// Get overall permission status (device admin is optional - only for uninstall prevention)
  bool get hasAllPermissions {
    return _hasUsageAccess && 
           _hasAccessibilityService && 
           _hasOverlayPermission;
  }

  /// Get missing permissions list
  List<String> get missingPermissions {
    final missing = <String>[];
    
    if (!_hasDeviceAdmin) missing.add('Device Administrator');
    if (!_hasUsageAccess) missing.add('Usage Access');
    if (!_hasAccessibilityService) missing.add('Accessibility Service');
    if (!_hasOverlayPermission) missing.add('Display over other apps');
    
    return missing;
  }

  /// Request all required permissions in sequence with delays
  Future<bool> requestAllPermissions() async {
    if (!Platform.isAndroid) return false;
    
    // Just open the general permissions screen and let user handle manually
    try {
      await _channel.invokeMethod('requestPermissions');
      await Future.delayed(const Duration(seconds: 2));
      await _checkAllPermissions();
      return hasAllPermissions;
    } catch (e) {
      debugPrint('Error requesting all permissions: $e');
      return false;
    }
  }

  /// Open app settings for manual permission management
  Future<void> openAppSettings() async {
    if (!Platform.isAndroid) return;
    
    try {
      await _channel.invokeMethod('openAppSettings');
    } catch (e) {
      debugPrint('Error opening app settings: $e');
    }
  }

  /// Get permission status summary
  Map<String, bool> get permissionStatus {
    return {
      'deviceAdmin': _hasDeviceAdmin,
      'usageAccess': _hasUsageAccess,
      'accessibilityService': _hasAccessibilityService,
      'overlayPermission': _hasOverlayPermission,
    };
  }
}