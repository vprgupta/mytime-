import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/modern_card.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final MethodChannel _channel = const MethodChannel('app_blocking');
  
  // Permission states
  bool _usageStatsGranted = false;
  bool _accessibilityGranted = false;
  bool _overlayGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final permissions = await _channel.invokeMethod<Map>('checkPermissions');
      if (permissions != null) {
        setState(() {
          _usageStatsGranted = permissions['usageStats'] ?? false;
          _accessibilityGranted = permissions['accessibility'] ?? false;
          _overlayGranted = permissions['overlay'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    if (mounted) {
      context.go('/dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (Hidden on first page)
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSecondary),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                    )
                  else
                    const SizedBox(width: 48), // Spacer to keep layout balanced

                  // Skip Button (Hidden on last page)
                  if (_currentPage < 4)
                    TextButton(
                      onPressed: () => _pageController.animateToPage(
                        4,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      child: const Text(
                        'Skip',
                        style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    const SizedBox(width: 64), // Spacer
                ],
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  if (index == 4) _checkPermissions();
                },
                children: [
                  _buildSlide(
                    icon: Icons.hourglass_empty_rounded,
                    title: 'Take Back Your Time',
                    description: 'Regain control over your digital life. MyTime helps you focus on what truly matters by managing your screen time effectively.',
                    color: AppColors.primaryBlue,
                  ),
                  _buildSlide(
                    icon: Icons.block_rounded,
                    title: 'Block Distractions',
                    description: 'Select distracting apps and block them instantly. Create schedules to automate your focus hours and boost productivity.',
                    color: AppColors.warningOrange,
                  ),
                  _buildSlide(
                    icon: Icons.lock_outline_rounded,
                    title: 'Stay Committed',
                    description: 'Need extra discipline? Use "Commitment Mode" to prevent uninstallation and strictly enforce your limits. No cheating allowed!',
                    color: AppColors.dangerRed,
                  ),
                  _buildSlide(
                    icon: Icons.security_rounded,
                    title: 'Your Data is Safe',
                    description: 'We respect your privacy. All blocking logic runs locally on your device. We do not sell or share your personal usage data.',
                    color: AppColors.successGreen,
                    extraContent: Container(
                      margin: const EdgeInsets.only(top: 24),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.successGreen.withValues(alpha:0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.successGreen.withValues(alpha:0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user_rounded, size: 16, color: AppColors.successGreen),
                          SizedBox(width: 8),
                          Text(
                            '100% Offline & Private',
                            style: TextStyle(
                              color: AppColors.successGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildPermissionSlide(),
                ],
              ),
            ),

            // Bottom Navigation Area
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Page Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: _currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primaryBlue
                              : AppColors.textSecondary.withValues(alpha:0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 32),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      text: _currentPage == 4 ? 'Get Started' : 'Next',
                      icon: _currentPage == 4 ? Icons.rocket_launch : Icons.arrow_forward,
                      onPressed: () {
                        if (_currentPage < 4) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _completeOnboarding();
                        }
                      },
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

  Widget _buildSlide({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    Widget? extraContent,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: color.withValues(alpha:0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 80, color: color),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          if (extraContent != null) extraContent,
        ],
      ),
    );
  }

  Widget _buildPermissionSlide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.settings_accessibility_rounded, size: 64, color: AppColors.primaryBlue),
          const SizedBox(height: 24),
          const Text(
            'Permissions Needed',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'To work effectively, MyTime needs a few permissions. You can grant them now or later.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          
          _buildPermissionItem(
            'Usage Statistics',
            'To track screen time and detect app usage.',
            _usageStatsGranted,
            () async {
              await _channel.invokeMethod('requestUsageStats');
              // Wait a bit for user to return
              await Future.delayed(const Duration(seconds: 1)); 
              _checkPermissions();
            },
          ),
          const SizedBox(height: 16),
          _buildPermissionItem(
            'Accessibility Service',
            'To block apps and prevent distraction.',
            _accessibilityGranted,
            () async {
              await _channel.invokeMethod('openAccessibilitySettings');
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissions();
            },
          ),
          const SizedBox(height: 16),
          _buildPermissionItem(
            'Display Over Apps',
            'To show the blocking screen.',
            _overlayGranted,
            () async {
              await _channel.invokeMethod('requestOverlay');
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem(String title, String subtitle, bool isGranted, VoidCallback onTap) {
    return ModernCard(
      onTap: isGranted ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isGranted ? Icons.check_circle : Icons.circle_outlined,
              color: isGranted ? AppColors.successGreen : AppColors.textSecondary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (!isGranted)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
