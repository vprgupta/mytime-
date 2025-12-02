import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../../core/widgets/modern_card.dart';

class PermissionSetupScreenV2 extends StatefulWidget {
  const PermissionSetupScreenV2({super.key});

  @override
  State<PermissionSetupScreenV2> createState() => _PermissionSetupScreenV2State();
}

class _PermissionSetupScreenV2State extends State<PermissionSetupScreenV2> {
  static const MethodChannel _channel = MethodChannel('app_blocking');
  
  bool _usageAccess = false;
  bool _accessibility = false;
  bool _overlay = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final result = await _channel.invokeMethod('checkPermissions');
      if (result is Map) {
        setState(() {
          _usageAccess = result['usageStats'] == true;
          _accessibility = result['accessibility'] == true;
          _overlay = result['overlay'] == true;
        });
      }
    } catch (e) {
      // debugPrint('Error checking permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Setup Permissions', style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'To block apps effectively, MyTask needs the following permissions:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 24),
          
          _buildPermissionCard(
            title: 'Usage Access',
            description: 'Required to detect which app you are currently using.',
            isGranted: _usageAccess,
            onTap: () async {
              await _channel.invokeMethod('requestUsageStats');
              await Future.delayed(const Duration(seconds: 1)); // Wait for user action
              _checkPermissions();
            },
          ),
          
          const SizedBox(height: 16),
          
          _buildPermissionCard(
            title: 'Accessibility Service',
            description: 'Required to detect app launches and block them immediately.',
            isGranted: _accessibility,
            onTap: () async {
              await _channel.invokeMethod('openAccessibilitySettings');
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissions();
            },
          ),
          
          const SizedBox(height: 16),
          
          _buildPermissionCard(
            title: 'Display Over Other Apps',
            description: 'Required to show the blocking screen over other apps.',
            isGranted: _overlay,
            onTap: () async {
              await _channel.invokeMethod('requestOverlay');
              await Future.delayed(const Duration(seconds: 1));
              _checkPermissions();
            },
          ),
          

          
          const SizedBox(height: 32),
          
          if (_usageAccess && _accessibility && _overlay)
            GradientButton(
              text: 'All Set! Continue',
              onPressed: () => Navigator.pop(context),
            ),
            

        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onTap,
  }) {
    return ModernCard(
      onTap: isGranted ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            isGranted 
                ? Lottie.asset(
                    'assets/animations/checked.json',
                    width: 40,
                    height: 40,
                    repeat: false,
                  )
                : Icon(
                    Icons.error_outline,
                    color: AppColors.warningOrange,
                    size: 32,
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!isGranted)
              const Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
