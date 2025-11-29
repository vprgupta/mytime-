import 'package:flutter/material.dart';

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
  bool _isActive = false;
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void startTour() {
    setState(() {
      _isActive = true;
      _currentStep = 0;
    });
    _animationController.forward();
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
              // Dark overlay
              Container(
                color: Colors.black.withValues(alpha: 0.7),
                child: GestureDetector(
                  onTap: () {}, // Prevent taps on overlay
                ),
              ),
              
              // Spotlight effect
              if (step.targetKey != null)
                _buildSpotlight(step.targetKey!),
              
              // Tour content
              Positioned(
                left: 20,
                right: 20,
                bottom: 100,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildTourCard(step),
                ),
              ),
              
              // Progress indicator
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

  Widget _buildSpotlight(GlobalKey targetKey) {
    return CustomPaint(
      size: Size.infinite,
      painter: SpotlightPainter(targetKey: targetKey),
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
            color: Colors.black.withValues(alpha: 0.2),
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
                  color: step.color.withValues(alpha: 0.1),
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
            color: Colors.white.withValues(alpha: 0.9),
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
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.steps[_currentStep].color,
            ),
          ),
        ),
      ],
    );
  }
}

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

class SpotlightPainter extends CustomPainter {
  final GlobalKey targetKey;

  SpotlightPainter({required this.targetKey});

  @override
  void paint(Canvas canvas, Size size) {
    final RenderBox? renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;

    final paint = Paint()
      ..color = Colors.white
      ..blendMode = BlendMode.clear;

    final center = Offset(
      position.dx + targetSize.width / 2,
      position.dy + targetSize.height / 2,
    );

    final radius = (targetSize.width > targetSize.height ? targetSize.width : targetSize.height) / 2 + 20;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Tour controller for managing tours across the app
class TourController {
  static final TourController _instance = TourController._internal();
  factory TourController() => _instance;
  TourController._internal();

  final Map<String, GlobalKey> _keys = {};

  void registerKey(String id, GlobalKey key) {
    _keys[id] = key;
  }

  GlobalKey? getKey(String id) {
    return _keys[id];
  }

  void startFeatureTour(BuildContext context) {
    final steps = [
      TourStep(
        title: 'Welcome to MyTask!',
        description: 'Your all-in-one productivity companion. Let\'s take a quick tour of the amazing features.',
        icon: Icons.waving_hand,
        color: const Color(0xFF6A5AE0),
      ),
      TourStep(
        title: 'Task Management',
        description: 'Create, organize, and track your tasks with smart categories and priority levels.',
        icon: Icons.task_alt,
        color: const Color(0xFF059669),
        targetKey: _keys['tasks'],
      ),
      TourStep(
        title: 'Focus Timer',
        description: 'Boost productivity with Pomodoro technique and customizable focus sessions.',
        icon: Icons.timer,
        color: const Color(0xFFDC2626),
        targetKey: _keys['timer'],
      ),
      TourStep(
        title: 'Password Vault',
        description: 'Securely store and manage all your passwords with military-grade encryption.',
        icon: Icons.security,
        color: const Color(0xFF7C3AED),
        targetKey: _keys['passwords'],
      ),
      TourStep(
        title: 'Daily Journal',
        description: 'Capture your thoughts, ideas, and reflections in your private digital journal.',
        icon: Icons.book,
        color: const Color(0xFFF59E0B),
        targetKey: _keys['journal'],
      ),
      TourStep(
        title: 'You\'re All Set!',
        description: 'Start your productivity journey now. Remember, small steps lead to big achievements!',
        icon: Icons.celebration,
        color: const Color(0xFF6A5AE0),
      ),
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppTour(
        steps: steps,
        onComplete: () => Navigator.of(context).pop(),
        child: Container(),
      ),
    );
  }
}