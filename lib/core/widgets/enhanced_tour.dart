import 'package:flutter/material.dart';

class EnhancedTourController {
  static final EnhancedTourController _instance = EnhancedTourController._internal();
  factory EnhancedTourController() => _instance;
  EnhancedTourController._internal();

  void startWelcomeTour(BuildContext context) {
    final steps = [
      TourStep(
        title: 'Welcome to MyTask! 🎉',
        description: 'Your all-in-one productivity companion designed to help you achieve your goals. Let\'s explore the amazing features that will transform your daily routine.',
        icon: Icons.waving_hand,
        color: const Color(0xFF6A5AE0),
      ),
      TourStep(
        title: 'Daily Schedule Hub 📅',
        description: 'Your home screen shows your complete daily schedule with morning, afternoon, and evening sections. Track progress, manage tasks, and stay motivated with streaks!',
        icon: Icons.home,
        color: const Color(0xFF059669),
      ),
      TourStep(
        title: 'Smart Task Management ✅',
        description: 'Create study sessions, breaks, and meals. Each task has timers, progress tracking, and smart notifications to keep you on track.',
        icon: Icons.task_alt,
        color: const Color(0xFF3B82F6),
      ),
      TourStep(
        title: 'Secure Password Vault 🔐',
        description: 'Store all your passwords securely with military-grade encryption. Generate strong passwords and access them safely.',
        icon: Icons.security,
        color: const Color(0xFF7C3AED),
      ),
      TourStep(
        title: 'Digital Journal 📖',
        description: 'Capture your thoughts, ideas, and daily reflections. Your private space for creativity and self-reflection.',
        icon: Icons.book,
        color: const Color(0xFFF59E0B),
      ),
      TourStep(
        title: 'Smart Reminders ⏰',
        description: 'Never miss important tasks with intelligent reminders that adapt to your schedule and preferences.',
        icon: Icons.notifications,
        color: const Color(0xFFEF4444),
      ),
      TourStep(
        title: 'You\'re All Set! 🚀',
        description: 'Start your productivity journey now! Remember: small consistent steps lead to big achievements. Tap the tour icon anytime for help.',
        icon: Icons.celebration,
        color: const Color(0xFF6A5AE0),
      ),
    ];

    _showTourDialog(context, steps, 'Welcome Tour');
  }

  void startNavigationTour(BuildContext context) {
    final steps = [
      TourStep(
        title: 'Navigation Made Easy 🧭',
        description: 'Let\'s explore how to navigate through MyTask efficiently using the bottom navigation bar.',
        icon: Icons.explore,
        color: const Color(0xFF6A5AE0),
      ),
      TourStep(
        title: 'Home - Your Command Center 🏠',
        description: 'The home screen is your daily dashboard. View your schedule, track progress, and manage your day from here.',
        icon: Icons.home,
        color: const Color(0xFF059669),
      ),
      TourStep(
        title: 'Journal - Your Thoughts 📝',
        description: 'Access your digital journal to write thoughts, ideas, and daily reflections. Your private creative space.',
        icon: Icons.book,
        color: const Color(0xFFF59E0B),
      ),
      TourStep(
        title: 'Reminders - Stay On Track ⏰',
        description: 'Set up and manage reminders for important tasks, deadlines, and personal goals.',
        icon: Icons.alarm,
        color: const Color(0xFFEF4444),
      ),
      TourStep(
        title: 'Passwords - Secure Vault 🔒',
        description: 'Manage all your passwords securely. Generate, store, and access your credentials safely.',
        icon: Icons.lock,
        color: const Color(0xFF7C3AED),
      ),
      TourStep(
        title: 'Settings - Customize Your Experience ⚙️',
        description: 'Personalize MyTask to fit your needs. Adjust preferences, themes, and app behavior.',
        icon: Icons.settings,
        color: const Color(0xFF6B7280),
      ),
    ];

    _showTourDialog(context, steps, 'Navigation Tour');
  }

  void startFeatureTour(BuildContext context) {
    final steps = [
      TourStep(
        title: 'Feature Deep Dive 🔍',
        description: 'Let\'s explore the powerful features that make MyTask your ultimate productivity companion.',
        icon: Icons.explore,
        color: const Color(0xFF6A5AE0),
      ),
      TourStep(
        title: 'Schedule Sections 📊',
        description: 'Your day is organized into Morning, Afternoon, and Evening sections. Each section shows progress and allows you to add tasks.',
        icon: Icons.view_timeline,
        color: const Color(0xFF059669),
      ),
      TourStep(
        title: 'Task Types & Timers ⏱️',
        description: 'Create Study sessions (40 min), Breaks (10 min), or Meals (60 min). Each has built-in timers and progress tracking.',
        icon: Icons.timer,
        color: const Color(0xFF3B82F6),
      ),
      TourStep(
        title: 'Streak System 🔥',
        description: 'Build daily streaks to stay motivated! Set challenges, track progress, and level up your productivity game.',
        icon: Icons.local_fire_department,
        color: const Color(0xFFEF4444),
      ),
      TourStep(
        title: 'Progress Analytics 📈',
        description: 'Monitor your daily completion rates, study vs break balance, and overall productivity trends.',
        icon: Icons.analytics,
        color: const Color(0xFF8B5CF6),
      ),
      TourStep(
        title: 'Smart Notifications 🔔',
        description: 'Get intelligent reminders for task starts, breaks, and important deadlines based on your schedule.',
        icon: Icons.notifications_active,
        color: const Color(0xFFF59E0B),
      ),
    ];

    _showTourDialog(context, steps, 'Feature Tour');
  }

  void startQuickTips(BuildContext context) {
    final steps = [
      TourStep(
        title: 'Pro Tips & Tricks 💡',
        description: 'Master MyTask with these expert tips to maximize your productivity and efficiency.',
        icon: Icons.lightbulb,
        color: const Color(0xFF6A5AE0),
      ),
      TourStep(
        title: 'Quick Task Creation ⚡',
        description: 'Tap the + button in any section to quickly add tasks. The app auto-suggests times based on your existing schedule.',
        icon: Icons.add_circle,
        color: const Color(0xFF059669),
      ),
      TourStep(
        title: 'Batch Operations 📦',
        description: 'Use the refresh button to reset your entire day, or activate whole sections with the "Start Session" button.',
        icon: Icons.refresh,
        color: const Color(0xFF3B82F6),
      ),
      TourStep(
        title: 'Time Management 🎯',
        description: 'Edit section time ranges by tapping the schedule icon. Customize your day to match your natural rhythm.',
        icon: Icons.schedule,
        color: const Color(0xFFEF4444),
      ),
      TourStep(
        title: 'Password Security 🛡️',
        description: 'Use the password generator for strong, unique passwords. Enable auto-lock for extra security.',
        icon: Icons.shield,
        color: const Color(0xFF7C3AED),
      ),
      TourStep(
        title: 'Daily Wisdom 🌟',
        description: 'Check your home screen daily for motivational quotes and wisdom to keep you inspired throughout your journey.',
        icon: Icons.auto_stories,
        color: const Color(0xFFF59E0B),
      ),
    ];

    _showTourDialog(context, steps, 'Pro Tips');
  }

  void _showTourDialog(BuildContext context, List<TourStep> steps, String tourName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppTour(
        steps: steps,
        onComplete: () {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$tourName completed! 🎉'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        child: Container(),
      ),
    );
  }

  void showTourMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'App Tours & Help 🎯',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a tour to learn about MyTask features',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            _buildTourOption(
              context,
              'Welcome Tour',
              'Perfect for new users - overview of all features',
              Icons.waving_hand,
              const Color(0xFF6A5AE0),
              () => startWelcomeTour(context),
            ),
            _buildTourOption(
              context,
              'Navigation Guide',
              'Learn how to navigate through the app',
              Icons.explore,
              const Color(0xFF059669),
              () => startNavigationTour(context),
            ),
            _buildTourOption(
              context,
              'Feature Deep Dive',
              'Explore advanced features and capabilities',
              Icons.explore_outlined,
              const Color(0xFF3B82F6),
              () => startFeatureTour(context),
            ),
            _buildTourOption(
              context,
              'Pro Tips & Tricks',
              'Master MyTask with expert tips',
              Icons.lightbulb,
              const Color(0xFFF59E0B),
              () => startQuickTips(context),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildTourOption(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: color.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(12),
              color: color.withOpacity(0.05),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Reuse existing TourStep and AppTour classes
class TourStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final GlobalKey? targetKey;

  TourStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.targetKey,
  });
}

class AppTour extends StatefulWidget {
  final Widget child;
  final List<TourStep> steps;
  final VoidCallback? onComplete;

  const AppTour({
    super.key,
    required this.child,
    required this.steps,
    this.onComplete,
  });

  @override
  State<AppTour> createState() => _AppTourState();
}

class _AppTourState extends State<AppTour> with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _isActive = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(_animationController);
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _completeTour();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  void _completeTour() {
    _animationController.reverse().then((_) {
      setState(() {
        _isActive = false;
      });
      widget.onComplete?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isActive) _buildTourOverlay(),
      ],
    );
  }

  Widget _buildTourOverlay() {
    final step = widget.steps[_currentStep];
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Stack(
            children: [
              Container(
                color: Colors.black.withOpacity(0.7),
                child: GestureDetector(
                  onTap: () {},
                ),
              ),
              
              Positioned(
                left: 20,
                right: 20,
                bottom: 100,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildTourCard(step),
                ),
              ),
              
              Positioned(
                top: 60,
                left: 20,
                right: 20,
                child: _buildProgressIndicator(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTourCard(TourStep step) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: step.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(step.icon, color: step.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            step.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (_currentStep > 0)
                TextButton(
                  onPressed: _previousStep,
                  child: const Text('Previous'),
                ),
              const Spacer(),
              TextButton(
                onPressed: _completeTour,
                child: const Text('Skip'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: step.color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentStep == widget.steps.length - 1 ? 'Finish' : 'Next',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${_currentStep + 1} of ${widget.steps.length}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / widget.steps.length,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.steps[_currentStep].color,
            ),
          ),
        ),
      ],
    );
  }
}