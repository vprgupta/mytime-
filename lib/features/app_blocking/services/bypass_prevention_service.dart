import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../models/bypass_attempt.dart';

class BypassPreventionService {
  static const MethodChannel _channel = MethodChannel('app_blocking');
  
  static Future<void> enableAntiBypassProtection() async {
    try {
      // Enable device admin for uninstall protection
      await _channel.invokeMethod('enableDeviceAdmin');
      
      // Start comprehensive protection
      await _channel.invokeMethod('preventUninstall', {'prevent': true});
      
    } catch (e) {
      debugPrint('Error enabling anti-bypass protection: $e');
    }
  }
  
  static Future<void> disableAntiBypassProtection() async {
    try {
      await _channel.invokeMethod('preventUninstall', {'prevent': false});
    } catch (e) {
      debugPrint('Error disabling anti-bypass protection: $e');
    }
  }
  
  static Future<bool> isDeviceAdminEnabled() async {
    try {
      return await _channel.invokeMethod('isDeviceAdminEnabled') ?? false;
    } catch (e) {
      debugPrint('Error checking device admin status: $e');
      return false;
    }
  }

  // Mock data for bypass attempts - in real implementation, this would come from storage
  List<BypassAttempt> getAllBypassAttempts() {
    return [];
  }

  List<BypassAttempt> getTodayBypassAttempts() {
    return [];
  }

  Map<String, int> getBypassAttemptsByType() {
    return {};
  }
}