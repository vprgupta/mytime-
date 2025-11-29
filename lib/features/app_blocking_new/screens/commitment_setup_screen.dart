import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/gradient_button.dart';

class CommitmentSetupScreen extends StatefulWidget {
  const CommitmentSetupScreen({Key? key}) : super(key: key);

  @override
  State<CommitmentSetupScreen> createState() => _CommitmentSetupScreenState();
}

class _CommitmentSetupScreenState extends State<CommitmentSetupScreen> {
  final MethodChannel _channel = const MethodChannel('app_blocking');
  final PageController _pageController = PageController();
  
  int _currentPage = 0;
  int _selectedHours = 1;
  Map<String, dynamic> _manufacturerInfo = {};
  Map<String, dynamic> _permissions = {};
  bool _batteryOptimized = false;
  bool _isActivating = false;
  
  @override
  void initState() {
    super.initState();
    _loadInfo();
  }
  
  Future<void> _loadInfo() async {
    try {
      final manufacturer = await _channel.invokeMethod<Map>('getManufacturerInfo');
      _manufacturerInfo = Map<String, dynamic>.from(manufacturer ?? {});
      
      final permissions = await _channel.invokeMethod<Map>('checkPermissions');
      _permissions = Map<String, dynamic>.from(permissions ?? {});
      
      final batteryStatus = await _channel.invokeMethod<bool>('getBatteryOptimizationStatus');
      _batteryOptimized = batteryStatus ?? false;
      
      setState(() {});
    } catch (e) {
      print('Error loading info: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Setup Commitment Mode', style: TextStyle(color: AppColors.textPrimary)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Page indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _currentPage ? 32 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _currentPage 
                        ? AppColors.primaryBlue 
                        : AppColors.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) => setState(() => _currentPage = page),
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: [
                _buildDurationPage(),
                _buildManufacturerPage(),
                _buildPermissionsPage(),
                _buildConfirmationPage(),
              ],
            ),
          ),
          
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Back', style: TextStyle(color: AppColors.textPrimary)),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 16),
                Expanded(
                  child: GradientButton(
                    text: _currentPage == 3 ? 'Activate' : 'Next',
                    icon: _currentPage == 3 ? Icons.lock : Icons.arrow_forward,
                    gradient: _currentPage == 3 ? AppColors.dangerGradient : AppColors.primaryGradient,
                    onPressed: _isActivating ? null : () async {
                      if (_currentPage == 3) {
                        await _activateCommitment();
                      } else {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDurationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⏰ Choose Duration',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'How long do you want to commit? You won\'t be able to unblock apps or uninstall this app during this time.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          
          // Testing option (kept at top for convenience)
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.warningOrange.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.warningOrange.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.science, color: AppColors.warningOrange, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'TESTING MODE',
                        style: TextStyle(
                          color: AppColors.warningOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildDurationOption(0, '5 Minutes', 'Quick test (for debugging)'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          _buildDurationOption(1, '1 Hour', 'Quick focus session'),
          const SizedBox(height: 12),
          _buildDurationOption(12, '12 Hours', 'Half-day commitment'),
          const SizedBox(height: 12),
          _buildDurationOption(24, '24 Hours', 'Full-day focus'),
          const SizedBox(height: 12),
          _buildDurationOption(24 * 7, '7 Days', 'Weekly commitment'),
          const SizedBox(height: 12),
          _buildDurationOption(24 * 30, '30 Days', 'Maximum commitment'),
        ],
      ),
    );
  }
  
  Widget _buildDurationOption(int hours, String label, String description) {
    final isSelected = _selectedHours == hours;
    
    return ModernCard(
      onTap: () => setState(() => _selectedHours = hours),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    AppColors.primaryBlue.withOpacity(0.2),
                    AppColors.primaryBlue.withOpacity(0.1),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryBlue
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
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
  
  Widget _buildManufacturerPage() {
    final manufacturer = _manufacturerInfo['manufacturer'] ?? 'Your Device';
    final instructions = _manufacturerInfo['instructions'] ?? 'No specific instructions available.';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📱 $manufacturer Setup',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'For commitment mode to work reliably, you need to disable battery optimization:',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _batteryOptimized ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: _batteryOptimized ? AppColors.successGreen : AppColors.warningOrange,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _batteryOptimized ? 'Battery Optimized ✓' : 'Battery Optimization',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    instructions,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                  ),
                  if (!_batteryOptimized) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        text: 'Open Battery Settings',
                        icon: Icons.battery_saver,
                        gradient: AppColors.warningGradient,
                        onPressed: () async {
                          await _channel.invokeMethod('openManufacturerBatterySettings');
                          // Reload status after 2 seconds
                          await Future.delayed(const Duration(seconds: 2));
                          await _loadInfo();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPermissionsPage() {
    final usageStats = _permissions['usageStats'] ?? false;
    final accessibility = _permissions['accessibility'] ?? false;
    final overlay = _permissions['overlay'] ?? false;
    final deviceAdmin = _permissions['deviceAdmin'] ?? false;
    
    final allRequired = usageStats && accessibility && overlay;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🔐 Permissions Check',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Grant these permissions for commitment mode to work:',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          
          _buildPermissionItem(
            'Usage Stats',
            usageStats,
            'Required',
            () async {
              await _channel.invokeMethod('requestUsageStats');
              await Future.delayed(const Duration(seconds: 1));
              await _loadInfo();
            },
          ),
          const SizedBox(height: 12),
          _buildPermissionItem(
            'Accessibility Service',
            accessibility,
            'Required',
            () async {
              await _channel.invokeMethod('openAccessibilitySettings');
              await Future.delayed(const Duration(seconds: 1));
              await _loadInfo();
            },
          ),
          const SizedBox(height: 12),
          _buildPermissionItem(
            'Display Over Apps',
            overlay,
            'Required',
            () async {
              await _channel.invokeMethod('requestOverlay');
              await Future.delayed(const Duration(seconds: 1));
              await _loadInfo();
            },
          ),
          const SizedBox(height: 12),
          _buildPermissionItem(
            'Device Admin',
            deviceAdmin,
            'Optional',
            () async {
              await _channel.invokeMethod('enableDeviceAdmin');
              await Future.delayed(const Duration(seconds: 1));
              await _loadInfo();
            },
          ),
          
          if (!allRequired) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warningOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningOrange.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.warningOrange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please grant all required permissions before proceeding.',
                      style: TextStyle(color: AppColors.warningOrange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPermissionItem(String title, bool isGranted, String badge, VoidCallback onGrant) {
    return ModernCard(
      child: ListTile(
        leading: Icon(
          isGranted ? Icons.check_circle : Icons.cancel,
          color: isGranted ? AppColors.successGreen : AppColors.textSecondary,
          size: 32,
        ),
        title: Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badge == 'Required' 
                    ? AppColors.dangerRed.withOpacity(0.2)
                    : AppColors.textSecondary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  color: badge == 'Required' ? AppColors.dangerRed : AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: isGranted
            ? null
            : TextButton(
                onPressed: onGrant,
                child: const Text('Grant', style: TextStyle(color: AppColors.primaryBlue)),
              ),
      ),
    );
  }
  
  Widget _buildConfirmationPage() {
    final hours = _selectedHours;
    final days = hours ~/ 24;
    final remainingHours = hours % 24;
    
    String durationText;
    if (hours == 0) {
      // Special case: Testing mode (5 minutes)
      durationText = '5 minutes';
    } else if (days > 0) {
      durationText = days == 1 ? '1 day' : '$days days';
      if (remainingHours > 0) {
        durationText += ' $remainingHours hours';
      }
    } else {
      durationText = hours == 1 ? '1 hour' : '$hours hours';
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠️ Final Confirmation',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please confirm you understand the following:',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWarningItem('You are committing for $durationText'),
                  const Divider(color: AppColors.border, height: 32),
                  _buildWarningItem('You cannot unblock apps during this time'),
                  const Divider(color: AppColors.border, height: 32),
                  _buildWarningItem('You cannot uninstall this app during this time'),
                  const Divider(color: AppColors.border, height: 32),
                  _buildWarningItem('This lock will survive phone restarts'),
                  const Divider(color: AppColors.border, height: 32),
                  _buildWarningItem('There is NO way to bypass this commitment'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.dangerRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.dangerRed.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock, color: AppColors.dangerRed),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Once activated, you must wait for the commitment to expire naturally.',
                    style: TextStyle(
                      color: AppColors.dangerRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWarningItem(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.primaryBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
  
  Future<void> _activateCommitment() async {
    setState(() => _isActivating = true);
    
    try {
      final success = await _channel.invokeMethod<bool>('startCommitmentMode', {
        'hours': _selectedHours,
      });
      
      if (success == true && mounted) {
        // Show success and go back
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔒 Commitment Mode Activated for $_selectedHours hours!'),
            backgroundColor: AppColors.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );
        
        Navigator.of(context).pop(true); // Return true to indicate success
      } else {
        throw Exception('Failed to activate commitment mode');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
