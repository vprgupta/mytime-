import 'dart:async';
import 'package:mytime/core/services/tts_service.dart';

class NotificationListenerService {
  static NotificationListenerService? _instance;
  static NotificationListenerService get instance => _instance ??= NotificationListenerService._();
  
  NotificationListenerService._();
  
  TTSService? _ttsService;
  Timer? _checkTimer;
  
  void init(TTSService ttsService) {
    _ttsService = ttsService;
    _startListening();
  }
  
  void _startListening() {
    // Check for notifications every 30 seconds when app is active
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkForActiveNotifications();
    });
  }
  
  void _checkForActiveNotifications() {
    // This would check for active notifications and speak them
    // For now, we'll rely on the immediate TTS in showNotification
  }
  
  void dispose() {
    _checkTimer?.cancel();
  }
  
  Future<void> handleNotificationWithTTS(String title, String body) async {
    if (_ttsService != null) {
      final textToSpeak = '$title. $body';
      await _ttsService!.speak(textToSpeak);
    }
  }
}