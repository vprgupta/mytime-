import 'dart:math';
import 'tts_service.dart';

class MotivationalQuotesService {
  static final TTSService _ttsService = TTSService();
  static final List<String> _billionaireQuotes = [
    "Success is not final, failure is not fatal. It's the courage to continue that counts. Keep pushing forward!",
    "The way to get started is to quit talking and begin doing. You just proved you can execute!",
    "Your limitation is only your imagination. You're breaking barriers with every completed task!",
    "Great things never come from comfort zones. You're building your empire one task at a time!",
    "Dream it. Wish it. Do it. You just did it! That's the billionaire mindset!",
    "Success doesn't just find you. You create it, you build it, you earn it. Well done, champion!",
    "The harder you work for something, the greater you'll feel when you achieve it. Feel that power!",
    "Don't stop when you're tired. Stop when you're done. You're unstoppable!",
    "Wake up with determination. Go to bed with satisfaction. You're living the dream!",
    "Do something today that your future self will thank you for. Mission accomplished!",
    "Little things make big things happen. You're building something massive!",
    "It's going to be hard, but hard does not mean impossible. You just proved it!",
    "Don't wait for opportunity. Create it. You're the architect of your success!",
    "The key to success is to focus on goals, not obstacles. You're laser-focused!",
    "Believe you can and you're halfway there. You just went all the way!",
    "Champions keep playing until they get it right. You're a true champion!",
    "Success is the sum of small efforts repeated day in and day out. You're compounding greatness!",
    "The difference between ordinary and extraordinary is that little extra. You have it!",
    "Opportunities don't happen. You create them. You just created another one!",
    "Be yourself; everyone else is already taken. You're uniquely powerful!",
    "The future belongs to those who believe in the beauty of their dreams. Keep dreaming big!",
    "It is during our darkest moments that we must focus to see the light. You're shining bright!",
    "Believe in yourself and all that you are. You're capable of amazing things!",
    "The only impossible journey is the one you never begin. You're already on your way!",
    "In the middle of difficulty lies opportunity. You're turning challenges into victories!"
  ];

  static String getRandomQuote() {
    final random = Random();
    return _billionaireQuotes[random.nextInt(_billionaireQuotes.length)];
  }
  
  static Future<void> speakMotivationalQuote() async {
    String quote = getRandomQuote();
    // Use higher pitch and slower rate for motivational content
    await _ttsService.speakWithEmotion(quote, pitch: 1.2, rate: 0.45);
  }
  
  static Future<void> speakCelebration(String message) async {
    // Enthusiastic voice for celebrations
    await _ttsService.speakWithEmotion(message, pitch: 1.3, rate: 0.6);
  }
  
  static Future<void> speakEncouragement(String message) async {
    // Warm, supportive voice for encouragement
    await _ttsService.speakWithEmotion(message, pitch: 1.1, rate: 0.4);
  }
}