import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:mytime/core/services/tts_service.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  TTSService? _ttsService;

  void setTTSService(TTSService ttsService) {
    _ttsService = ttsService;
  }

  Future<void> init([TTSService? ttsService]) async {
    if (ttsService != null) {
      _ttsService = ttsService;
    }
    
    // Initialize timezone data
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );
    
    // Request notification permissions for Android 13+
  }

  static void _onNotificationTapped(NotificationResponse response) {
    if (kDebugMode) debugPrint('Notification tapped: ${response.payload}');
  }

  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    // Handle background notification taps
    if (kDebugMode) debugPrint('Background notification tapped: ${response.payload}');
  }

  Future<void> showNotification(String title, String body, {String? soundType, bool speakText = true}) async {
    if (kDebugMode) debugPrint('Attempting to show notification: $title - $body');
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'mytask_main_channel',
      'MyTask Notifications',
      channelDescription: 'Main notification channel for MyTask app',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final textToSpeak = '$title. $body';
      
      await _flutterLocalNotificationsPlugin.show(
        notificationId,
        title,
        body,
        platformChannelSpecifics,
        payload: textToSpeak,
      );
      
      // Speak the notification text with delay to prevent state conflicts
      if (speakText && _ttsService != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _ttsService!.speak(textToSpeak);
        });
      }
      
      if (kDebugMode) debugPrint('Notification shown successfully with ID: $notificationId');
    } catch (e) {
      if (kDebugMode) debugPrint('Error showing notification: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
    if (kDebugMode) debugPrint('Cancelled notification with ID: $id');
  }
  
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
    if (kDebugMode) debugPrint('Cancelled all notifications');
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    bool speakText = true,
  }) async {
    if (kDebugMode) debugPrint('Scheduling notification for: $scheduledDate');
    
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'mytask_scheduled_channel',
      'MyTask Scheduled Notifications',
      channelDescription: 'Scheduled notifications for MyTask app',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      // Convert DateTime to TZDateTime
      final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);
      final textToSpeak = '$title. $body';
      
      // Check if the scheduled date is in the future
      if (scheduledTZDate.isAfter(tz.TZDateTime.now(tz.local))) {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          scheduledTZDate,
          platformChannelSpecifics,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          payload: textToSpeak,
        );
        if (kDebugMode) debugPrint('Notification scheduled successfully for: $scheduledTZDate');
      } else {
        if (kDebugMode) debugPrint('Scheduled date is in the past, showing immediate notification');
        await showNotification(title, body, speakText: speakText);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error scheduling notification: $e');
      // Fallback to immediate notification
      await showNotification(title, body, speakText: speakText);
    }
  }
}