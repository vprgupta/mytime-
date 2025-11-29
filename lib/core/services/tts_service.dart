import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';

class TTSService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> init() async {
    // Set language with better voice selection
    await _flutterTts.setLanguage("en-US");
    
    // Try to set a more natural voice
    if (Platform.isIOS) {
      await _flutterTts.setVoice({"name": "Samantha", "locale": "en-US"});
    } else if (Platform.isAndroid) {
      await _flutterTts.setVoice({"name": "en-us-x-sfg#female_2-local", "locale": "en-US"});
    }
    
    // Melodic speech settings
    await _flutterTts.setSpeechRate(0.5);  // Slightly slower for clarity
    await _flutterTts.setVolume(0.85);
    await _flutterTts.setPitch(1.1);  // Slightly higher pitch for warmth
    await _flutterTts.awaitSpeakCompletion(true);
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) await init();
    await _flutterTts.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Clean and enhance text for melodic speech
    String enhancedText = _enhanceTextForMelodicSpeech(text);
    await _flutterTts.speak(enhancedText);
  }
  
  Future<void> speakWithEmotion(String text, {double? pitch, double? rate}) async {
    if (!_isInitialized) await init();
    await _flutterTts.stop();
    
    // Temporarily adjust voice for emotion
    if (pitch != null) await _flutterTts.setPitch(pitch);
    if (rate != null) await _flutterTts.setSpeechRate(rate);
    
    String enhancedText = _enhanceTextForMelodicSpeech(text);
    await _flutterTts.speak(enhancedText);
    
    // Reset to default
    await _flutterTts.setPitch(1.1);
    await _flutterTts.setSpeechRate(0.5);
  }
  
  String _enhanceTextForMelodicSpeech(String text) {
    // Add natural pauses and emphasis for melodic speech
    String enhanced = text
        .replaceAll('"', '')
        .replaceAll(''', '')
        .replaceAll(''', '')
        // Add pauses for natural rhythm
        .replaceAll(',', ', ')  // Slight pause after commas
        .replaceAll('.', '. ')  // Pause after periods
        .replaceAll('!', '! ')  // Keep excitement with pause
        .replaceAll('?', '? ')  // Keep questioning tone with pause
        // Add emphasis markers
        .replaceAll('important', 'very important')
        .replaceAll('great', 'really great')
        .replaceAll('good', 'very good')
        .replaceAll('well done', 'excellent work')
        .replaceAll('congratulations', 'wonderful, congratulations')
        // Clean up multiple spaces and dots
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('..', '.')
        .trim();
    
    return enhanced;
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}