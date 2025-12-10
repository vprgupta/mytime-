import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_card.dart';

class AboutAppScreen extends StatefulWidget {
  const AboutAppScreen({super.key});

  @override
  State<AboutAppScreen> createState() => _AboutAppScreenState();
}

class _AboutAppScreenState extends State<AboutAppScreen> {
  bool _isHinglish = true; // Default to Hinglish

  void _toggleLanguage() {
    setState(() {
      _isHinglish = !_isHinglish;
    });
  }

  // Language-specific content
  String get _subtitle => _isHinglish 
    ? 'Apne Phone Ko Control Karo!'
    : 'Take Control of Your Phone!';

  String get _featuresTitle => _isHinglish ? 'क्या कर सकते हैं?' : 'What Can You Do?';
  
  String get _quickStartTitle => _isHinglish ? 'कैसे शुरू करें?' : 'How to Start?';
  
  String get _tipsTitle => _isHinglish ? 'अच्छी बातें याद रखो 💡' : 'Remember These Tips 💡';
  
  String get _questionsTitle => _isHinglish ? 'सवाल-जवाब ❓' : 'Questions & Answers ❓';

  // Feature 1: App Blocking
  Map<String, String> get _feature1 => _isHinglish ? {
    'title': '📱 Apps को बंद करो',
    'subtitle': 'Distracting apps ko band karo',
    'description': '🎯 Kya hota hai?\n'
        'Jab tum kisi app ko block karte ho, wo app khulega hi nahi!\n\n'
        '📖 Example:\n'
        'Agar tum Instagram ko block kar do, to jab bhi tum Instagram kholne ki koshish karoge, wo nahi khulega. Ek message aayega \"This app is blocked\".\n\n'
        '🎮 Kab use karo?\n'
        '• Homework karte time\n'
        '• Padhai ke time\n'
        '• Sone se pehle\n\n'
        '✨ Kaise karo?\n'
        '1. \"App Control\" button dabao\n'
        '2. Jo apps block karni hain wo select karo\n'
        '3. \"Block\" button dabao\n'
        '4. Done! Ab wo apps nahi khulenge',
  } : {
    'title': '📱 Block Apps',
    'subtitle': 'Stop distracting apps from opening',
    'description': '🎯 What happens?\n'
        'When you block an app, it won\'t open at all!\n\n'
        '📖 Example:\n'
        'If you block Instagram, whenever you try to open it, it won\'t open. You\'ll see a message \"This app is blocked\".\n\n'
        '🎮 When to use?\n'
        '• During homework time\n'
        '• While studying\n'
        '• Before bedtime\n\n'
        '✨ How to do it?\n'
        '1. Tap \"App Control\" button\n'
        '2. Select apps you want to block\n'
        '3. Tap \"Block\" button\n'
        '4. Done! Those apps won\'t open now',
  };

  // Feature 2: Usage Limits
  Map<String, String> get _feature2 => _isHinglish ? {
    'title': '⏰ Time Limit लगाओ',
    'subtitle': 'Har app ke liye daily time set karo',
    'description': '🎯 Kya hota hai?\n'
        'Tum decide kar sakte ho ki ek app ko kitni der use karoge. Time khatam hone par app automatically band ho jayega!\n\n'
        '📖 Example:\n'
        'Agar tum YouTube ko 30 minutes ka limit do, to tum sirf 30 minutes YouTube dekh paoge. Uske baad YouTube khulega hi nahi. Kal fir se 30 minutes milenge.\n\n'
        '🎮 Kab use karo?\n'
        '• Games zyada na khelo\n'
        '• Social media kam use karo\n'
        '• Videos dekhne ka time control karo\n\n'
        '✨ Kaise karo?\n'
        '1. \"Usage Limiter\" pe jao\n'
        '2. App select karo (jaise YouTube)\n'
        '3. Time select karo (jaise 30 minutes)\n'
        '4. Save karo\n'
        '5. Ab tum sirf utna hi time use kar paoge!',
  } : {
    'title': '⏰ Set Time Limits',
    'subtitle': 'Control how long you use each app',
    'description': '🎯 What happens?\n'
        'You can decide how long to use an app each day. When time runs out, the app automatically stops!\n\n'
        '📖 Example:\n'
        'If you set YouTube to 30 minutes, you can only watch YouTube for 30 minutes. After that, YouTube won\'t open. Tomorrow you\'ll get 30 minutes again.\n\n'
        '🎮 When to use?\n'
        '• Don\'t play games too much\n'
        '• Use social media less\n'
        '• Control video watching time\n\n'
        '✨ How to do it?\n'
        '1. Go to \"Usage Limiter\"\n'
        '2. Select app (like YouTube)\n'
        '3. Choose time (like 30 minutes)\n'
        '4. Save it\n'
        '5. Now you can only use it for that long!',
  };

  // Feature 3: Schedules
  Map<String, String> get _feature3 => _isHinglish ? {
    'title': '📅 Time Table बनाओ',
    'subtitle': 'Apps ko sirf kuch time pe hi use karo',
    'description': '🎯 Kya hota hai?\n'
        'Tum decide kar sakte ho ki ek app sirf kuch specific time pe hi khule. Baaki time wo band rahega!\n\n'
        '📖 Example:\n'
        'Agar tum Instagram ko sirf shaam 6-8 baje allow karo, to Instagram sirf us time khulega. Subah, dopahar, raat - kisi bhi aur time nahi khulega.\n\n'
        '🎮 Kab use karo?\n'
        '• Games sirf shaam ko\n'
        '• Social media sirf break time\n'
        '• Videos sirf free time mein\n\n'
        '✨ Kaise karo?\n'
        '1. App select karo\n'
        '2. \"Add Schedule\" dabao\n'
        '3. Time select karo (jaise 6 PM se 8 PM)\n'
        '4. Enable karo\n'
        '5. Ab app sirf us time khulega!',
  } : {
    'title': '📅 Create Schedule',
    'subtitle': 'Use apps only at specific times',
    'description': '🎯 What happens?\n'
        'You can decide when an app can be used. It will only open during that time!\n\n'
        '📖 Example:\n'
        'If you allow Instagram only from 6-8 PM, Instagram will only open during that time. Morning, afternoon, night - it won\'t open any other time.\n\n'
        '🎮 When to use?\n'
        '• Games only in evening\n'
        '• Social media only during breaks\n'
        '• Videos only in free time\n\n'
        '✨ How to do it?\n'
        '1. Select app\n'
        '2. Tap \"Add Schedule\"\n'
        '3. Choose time (like 6 PM to 8 PM)\n'
        '4. Enable it\n'
        '5. Now app will only open during that time!',
  };

  // Feature 4: Commitment Mode
  Map<String, String> get _feature4 => _isHinglish ? {
    'title': '🔒 Pakka Promise Mode',
    'subtitle': 'Ek baar set kiya to badal nahi sakte',
    'description': '🎯 Kya hota hai?\n'
        'Jab tum ye mode ON karte ho, tum apne rules change nahi kar sakte! Ye tumhe apne promise pe pakka rehne mein madad karta hai.\n\n'
        '📖 Example:\n'
        'Agar kal tumhara exam hai aur tum 24 hours ke liye Commitment Mode ON karo, to:\n'
        '• Tum apps unblock nahi kar sakte\n'
        '• Time limits change nahi kar sakte\n'
        '• MyTime app delete nahi kar sakte\n'
        '• 24 hours baad hi sab normal hoga\n\n'
        '⚠️ BAHUT IMPORTANT:\n'
        '• Ek baar ON kiya to OFF nahi kar sakte\n'
        '• Time khatam hone tak wait karna padega\n'
        '• Koi cheating nahi!\n\n'
        '🎮 Kab use karo?\n'
        '• Exam se pehle\n'
        '• Important kaam karte time\n'
        '• Jab tum seriously focus karna chahte ho\n\n'
        '✨ Kaise karo?\n'
        '1. Pehle sare blocks/limits set karo\n'
        '2. \"Commitment Mode\" pe jao\n'
        '3. Time choose karo (1 hour se 30 days)\n'
        '4. Confirm karo\n'
        '5. Ab koi change nahi kar sakte!',
  } : {
    'title': '🔒 Strong Promise Mode',
    'subtitle': 'Once set, you cannot change it',
    'description': '🎯 What happens?\n'
        'When you turn this ON, you cannot change your rules! This helps you keep your promise.\n\n'
        '📖 Example:\n'
        'If you have an exam tomorrow and you turn ON Commitment Mode for 24 hours:\n'
        '• You cannot unblock apps\n'
        '• Cannot change time limits\n'
        '• Cannot delete MyTime app\n'
        '• Everything becomes normal only after 24 hours\n\n'
        '⚠️ VERY IMPORTANT:\n'
        '• Once ON, cannot turn OFF\n'
        '• Must wait until time finishes\n'
        '• No cheating!\n\n'
        '🎮 When to use?\n'
        '• Before exams\n'
        '• During important work\n'
        '• When you seriously want to focus\n\n'
        '✨ How to do it?\n'
        '1. First set all blocks/limits\n'
        '2. Go to \"Commitment Mode\"\n'
        '3. Choose time (1 hour to 30 days)\n'
        '4. Confirm\n'
        '5. Now you cannot change anything!',
  };

  // Quick Start Steps
  List<Map<String, String>> get _quickStartSteps => _isHinglish ? [
    {
      'number': '1',
      'title': 'Permissions Do',
      'desc': 'App ko 3 permissions chahiye. Sab \"Allow\" kar do. Ye zaruri hai!'
    },
    {
      'number': '2',
      'title': 'Chhote Se Shuru Karo',
      'desc': 'Pehle sirf 1-2 apps block karo. Sab kuch ek saath mat karo.'
    },
    {
      'number': '3',
      'title': 'Time Limit Lagao',
      'desc': 'Reasonable time rakho (30-60 min). Bahut kam mat rakho.'
    },
    {
      'number': '4',
      'title': 'Promise Mode Baad Mein',
      'desc': 'Jab tum comfortable ho jao, tab hi use karo.'
    },
  ] : [
    {
      'number': '1',
      'title': 'Give Permissions',
      'desc': 'App needs 3 permissions. Allow all of them. This is necessary!'
    },
    {
      'number': '2',
      'title': 'Start Small',
      'desc': 'First block only 1-2 apps. Don\'t do everything at once.'
    },
    {
      'number': '3',
      'title': 'Set Time Limits',
      'desc': 'Keep reasonable time (30-60 min). Don\'t keep very less.'
    },
    {
      'number': '4',
      'title': 'Promise Mode Later',
      'desc': 'Use it only when you feel comfortable.'
    },
  ];

  // Tips
  List<Map<String, dynamic>> get _tips => _isHinglish ? [
    {'emoji': '✅', 'text': 'Pehle app blocking try karo - sabse aasan hai', 'color': Colors.green},
    {'emoji': '✅', 'text': 'Padhai/homework ke time schedule use karo', 'color': Colors.green},
    {'emoji': '✅', 'text': 'Realistic time limits rakho', 'color': Colors.green},
    {'emoji': '❌', 'text': 'Sab apps ek saath block mat karo', 'color': Colors.red},
    {'emoji': '❌', 'text': 'Bahut lambe promise mode mat lagao shuru mein', 'color': Colors.red},
  ] : [
    {'emoji': '✅', 'text': 'Try app blocking first - it\'s easiest', 'color': Colors.green},
    {'emoji': '✅', 'text': 'Use schedules during study/homework time', 'color': Colors.green},
    {'emoji': '✅', 'text': 'Keep realistic time limits', 'color': Colors.green},
    {'emoji': '❌', 'text': 'Don\'t block all apps at once', 'color': Colors.red},
    {'emoji': '❌', 'text': 'Don\'t set very long promise mode at start', 'color': Colors.red},
  ];

  // Common Q&A
  List<Map<String, String>> get _commonQA => _isHinglish ? [
    {
      'q': 'Kya main app ko wapas khol sakta hoon?',
      'a': 'Haan! Jab tak Promise Mode ON nahi hai, tum kisi bhi app ko unblock kar sakte ho. Bas \"App Control\" mein jao aur unblock karo.'
    },
    {
      'q': 'Time limit khatam hone par kya hoga?',
      'a': 'Jab tumhara time khatam ho jayega (jaise 30 minutes YouTube), to wo app automatically band ho jayega. Kal subah 12 baje fir se time milega.'
    },
    {
      'q': 'Kya main schedule badal sakta hoon?',
      'a': 'Haan! Jab tak Promise Mode ON nahi hai, tum schedule change kar sakte ho. Schedule screen mein jao aur edit karo.'
    },
    {
      'q': 'Promise Mode kaise band karoon?',
      'a': 'Tum nahi kar sakte! Ye Promise Mode ki khaasiyat hai. Tumhe time khatam hone tak wait karna padega. Isliye carefully use karo!'
    },
    {
      'q': 'Kya main MyTime app delete kar sakta hoon?',
      'a': 'Agar Promise Mode ON hai to nahi! Warna haan, tum delete kar sakte ho. Lekin delete karne se pehle sab blocks/limits band kar lo.'
    },
  ] : [
    {
      'q': 'Can I open the app again?',
      'a': 'Yes! As long as Promise Mode is not ON, you can unblock any app. Just go to \"App Control\" and unblock it.'
    },
    {
      'q': 'What happens when time limit ends?',
      'a': 'When your time finishes (like 30 minutes of YouTube), that app will automatically stop. You\'ll get time again tomorrow at 12 AM.'
    },
    {
      'q': 'Can I change the schedule?',
      'a': 'Yes! As long as Promise Mode is not ON, you can change schedules. Go to schedule screen and edit it.'
    },
    {
      'q': 'How to turn off Promise Mode?',
      'a': 'You cannot! That\'s the special thing about Promise Mode. You must wait until time finishes. So use it carefully!'
    },
    {
      'q': 'Can I delete MyTime app?',
      'a': 'If Promise Mode is ON, then no! Otherwise yes, you can delete. But before deleting, turn off all blocks/limits.'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('About MyTime'),
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        actions: [
          // Language Toggle Button
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _toggleLanguage,
              icon: const Icon(
                Icons.language,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              label: Text(
                _isHinglish ? 'English' : 'हिंग्लिश',
                style: const TextStyle(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Info Card
            ModernCard(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.hourglass_empty_rounded,
                      size: 64,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'MyTime',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Features Section
            Text(
              _featuresTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            _buildFeatureCard(
              icon: Icons.block_rounded,
              iconColor: Colors.red,
              content: _feature1,
            ),
            
            const SizedBox(height: 16),
            
            _buildFeatureCard(
              icon: Icons.timer_outlined,
              iconColor: Colors.orange,
              content: _feature2,
            ),
            
            const SizedBox(height: 16),
            
            _buildFeatureCard(
              icon: Icons.schedule_rounded,
              iconColor: Colors.blue,
              content: _feature3,
            ),
            
            const SizedBox(height: 16),
            
            _buildFeatureCard(
              icon: Icons.lock_outline_rounded,
              iconColor: Colors.purple,
              content: _feature4,
            ),
            
            const SizedBox(height: 32),
            
            // Quick Start Guide
            Text(
              _quickStartTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            ModernCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    for (int i = 0; i < _quickStartSteps.length; i++) ...[
                      _buildStep(_quickStartSteps[i]),
                      if (i < _quickStartSteps.length - 1) 
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Tips Section
            Text(
              _tipsTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            ModernCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    for (int i = 0; i < _tips.length; i++) ...[
                      _buildTip(_tips[i]),
                      if (i < _tips.length - 1) const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Common Questions
            Text(
              _questionsTitle,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            
            for (var qa in _commonQA) ...[
              _buildQA(qa['q']!, qa['a']!),
              const SizedBox(height: 12),
            ],
            
            const SizedBox(height: 32),
            
            // Footer
            Center(
              child: Column(
                children: [
                  Text(
                    _isHinglish 
                      ? 'Pyaar se banaya gaya ❤️'
                      : 'Made with love ❤️',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '© 2024 MyTime',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required Map<String, String> content,
  }) {
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        content['title']!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        content['subtitle']!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                content['description']!,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(Map<String, String> step) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryBlue, Color(0xFF1E88E5)],
            ),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step['number']!,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step['title']!,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                step['desc']!,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTip(Map<String, dynamic> tip) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tip['emoji'],
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            tip['text'],
            style: TextStyle(
              fontSize: 15,
              color: tip['color'],
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQA(String question, String answer) {
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.help_outline,
                  color: AppColors.primaryBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.successGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.successGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      answer,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
