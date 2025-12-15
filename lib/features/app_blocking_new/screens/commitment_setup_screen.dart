import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/gradient_button.dart';

class CommitmentSetupScreen extends StatefulWidget {
  const CommitmentSetupScreen({super.key});

  @override
  State<CommitmentSetupScreen> createState() => _CommitmentSetupScreenState();
}

class _CommitmentSetupScreenState extends State<CommitmentSetupScreen> {
  final MethodChannel _channel = const MethodChannel('app_blocking');
  final PageController _pageController = PageController();
  final TextEditingController _daysController = TextEditingController(text: '1');
  final TextEditingController _hoursController = TextEditingController(text: '0');
  
  int _currentPage = 0;
  int _selectedHours = 24; // Calculated from days + hours
  
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
      // debugPrint('Error loading info: $e');
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
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == _currentPage ? 32 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: index == _currentPage 
                        ? AppColors.primaryBlue 
                        : AppColors.textSecondary.withValues(alpha:0.3),
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
                _buildIntroAndPermissionPage(), // Step 1: Permissions
                _buildDurationPage(),           // Step 2: Duration
                _buildConfirmationPage(),       // Step 3: Confirm
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
                    text: _currentPage == 2 ? 'Activate' : 'Next',
                    icon: _currentPage == 2 ? Icons.lock : Icons.arrow_forward,
                    gradient: _currentPage == 2 ? AppColors.dangerGradient : AppColors.activeGradient,
                    onPressed: _isActivating ? null : () async {
                      if (_currentPage == 0) {
                        // Check permissions before proceeding
                        final deviceAdmin = _permissions['deviceAdmin'] ?? false;
                        if (!deviceAdmin) {
                          // Auto-request permission instead of just showing snackbar
                          await _channel.invokeMethod('enableDeviceAdmin');
                          // Wait a bit for user to potentially grant it
                          await Future.delayed(const Duration(seconds: 1));
                          await _loadInfo();
                          
                          // Check again
                          final updatedPermissions = await _channel.invokeMethod<Map>('checkPermissions');
                          final isGranted = updatedPermissions?['deviceAdmin'] ?? false;
                          
                          if (!isGranted) {
                             if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enable Device Admin permission to proceed.'),
                                    backgroundColor: AppColors.warningOrange,
                                  ),
                                );
                             }
                             return;
                          }
                        }
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else if (_currentPage == 2) {
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

  Widget _buildIntroAndPermissionPage() {
    final deviceAdmin = _permissions['deviceAdmin'] ?? false;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🛡️ Enable Protection',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'To prevent uninstallation during your commitment, MyTime needs Device Administrator permission.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          
          _buildPermissionItem(
            'Device Admin',
            deviceAdmin,
            'Required',
            () async {
              await _channel.invokeMethod('enableDeviceAdmin');
              await Future.delayed(const Duration(seconds: 1));
              await _loadInfo();
            },
          ),
          
          const SizedBox(height: 32),
          const Text(
            'Other Requirements',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Battery Optimization Check
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                      Expanded(
                        child: Text(
                          _batteryOptimized ? 'Battery Optimized' : 'Battery Optimization',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!_batteryOptimized)
                        TextButton(
                          onPressed: () async {
                            await _channel.invokeMethod('openManufacturerBatterySettings');
                            await Future.delayed(const Duration(seconds: 2));
                            await _loadInfo();
                          },
                          child: const Text('Fix'),
                        ),
                    ],
                  ),
                  if (!_batteryOptimized)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _manufacturerInfo['instructions'] ?? 'Please disable battery optimization.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                ],
              ),
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
            'Enter how long you want to commit. This cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          
          // Custom Duration Input
          ModernCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Commitment Duration',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Days Input
                  TextField(
                    controller: _daysController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Days',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      suffixText: 'days',
                      suffixStyle: const TextStyle(color: AppColors.textSecondary),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      _updateTotalHours();
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Hours Input
                  TextField(
                    controller: _hoursController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
                    decoration: InputDecoration(
                      labelText: 'Hours',
                      labelStyle: const TextStyle(color: AppColors.textSecondary),
                      suffixText: 'hours',
                      suffixStyle: const TextStyle(color: AppColors.textSecondary),
                      helperText: 'Optional - Enter 0-23 hours',
                      helperStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                      ),
                    ),
                    onChanged: (value) {
                      _updateTotalHours();
                    },
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Total Duration Display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock, color: AppColors.primaryBlue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Commitment',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _getTotalDurationText(),
                                style: const TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Info Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warningOrange.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warningOrange, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: For exam prep, try 7-15 days. For habit building, 21-30 days works best.',
                    style: TextStyle(
                      color: AppColors.warningOrange,
                      fontSize: 13,
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
  
  void _updateTotalHours() {
    setState(() {
      final days = int.tryParse(_daysController.text) ?? 0;
      final hours = int.tryParse(_hoursController.text) ?? 0;
      _selectedHours = (days * 24) + hours;
    });
  }
  
  String _getTotalDurationText() {
    final days = int.tryParse(_daysController.text) ?? 0;
    final hours = int.tryParse(_hoursController.text) ?? 0;
    
    if (days == 0 && hours == 0) {
      return 'Please enter a duration';
    }
    
    String result = '';
    if (days > 0) {
      result += '$days ${days == 1 ? 'day' : 'days'}';
    }
    if (hours > 0) {
      if (result.isNotEmpty) result += ' ';
      result += '$hours ${hours == 1 ? 'hour' : 'hours'}';
    }
    
    return result;
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
                    ? AppColors.dangerRed.withValues(alpha:0.2)
                    : AppColors.textSecondary.withValues(alpha:0.2),
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
              color: AppColors.dangerRed.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.dangerRed.withValues(alpha:0.3)),
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
    _daysController.dispose();
    _hoursController.dispose();
    super.dispose();
  }
}
