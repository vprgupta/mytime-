import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/gradient_button.dart';

class CommitmentDiagnosticScreen extends StatefulWidget {
  const CommitmentDiagnosticScreen({super.key});

  @override
  State<CommitmentDiagnosticScreen> createState() => _CommitmentDiagnosticScreenState();
}

class _CommitmentDiagnosticScreenState extends State<CommitmentDiagnosticScreen> {
  final MethodChannel _channel = const MethodChannel('app_blocking');
  
  bool _isLoading = true;
  Map<String, dynamic> _permissions = {};
  Map<String, dynamic> _commitmentStatus = {};
  Map<String, dynamic> _manufacturerInfo = {};
  bool _batteryOptimized = false;
  
  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }
  
  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);
    
    try {
      // Check permissions
      final permissions = await _channel.invokeMethod<Map>('checkPermissions');
      _permissions = Map<String, dynamic>.from(permissions ?? {});
      
      // Get commitment status
      final status = await _channel.invokeMethod<Map>('getCommitmentStatus');
      _commitmentStatus = Map<String, dynamic>.from(status ?? {});
      
      // Get manufacturer info
      final manufacturer = await _channel.invokeMethod<Map>('getManufacturerInfo');
      _manufacturerInfo = Map<String, dynamic>.from(manufacturer ?? {});
      
      // Check battery optimization
      final batteryStatus = await _channel.invokeMethod<bool>('getBatteryOptimizationStatus');
      _batteryOptimized = batteryStatus ?? false;
      
      setState(() => _isLoading = false);
    } catch (e) {
      // debugPrint('Error loading diagnostics: $e');
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Commitment Diagnostics', style:TextStyle(color: AppColors.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDiagnostics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDeviceInfo(),
                    const SizedBox(height: 24),
                    _buildCommitmentStatus(),
                    const SizedBox(height: 24),
                    _buildPermissionsSection(),
                    const SizedBox(height: 24),
                    _buildBatteryOptimization(),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildDeviceInfo() {
    final manufacturer = _manufacturerInfo['manufacturer'] ?? 'Unknown';
    final model = _manufacturerInfo['model'] ?? 'Unknown';
    final androidVersion = _manufacturerInfo['androidVersion'] ?? 0;
    
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.phone_android, color: AppColors.primaryBlue, size: 24),
                SizedBox(width: 12),
                Text(
                  'Device Information',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Manufacturer', manufacturer),
            _buildInfoRow('Model', model),
            _buildInfoRow('Android Version', androidVersion.toString()),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCommitmentStatus() {
    final isActive = _commitmentStatus['isActive'] ?? false;

    final remainingTime = _commitmentStatus['remainingTime'] ?? 0;
    
    final remainingHours = remainingTime ~/ (1000 * 60 * 60);
    final remainingMinutes = (remainingTime ~/ (1000 * 60)) % 60;
    
    return ModernCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.lock : Icons.lock_open,
                  color: isActive ? AppColors.dangerRed : AppColors.textSecondary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Commitment Status',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive 
                    ? AppColors.dangerRed.withValues(alpha:0.1)
                    : AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? AppColors.dangerRed.withValues(alpha:0.3)
                      : AppColors.border.withValues(alpha:0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status:',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      Text(
                        isActive ? 'ACTIVE' : 'Inactive',
                        style: TextStyle(
                          color: isActive ? AppColors.dangerRed : AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (isActive) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Remaining:',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        Text(
                          '${remainingHours}h ${remainingMinutes}m',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPermissionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Required Permissions',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildPermissionCard(
          'Usage Stats',
          _permissions['usageStats'] ?? false,
          'Required to monitor app usage',
          () async {
            await _channel.invokeMethod('requestUsageStats');
          },
        ),
        const SizedBox(height: 8),
        _buildPermissionCard(
          'Accessibility Service',
          _permissions['accessibility'] ?? false,
          'Required to block apps',
          () async {
            await _channel.invokeMethod('openAccessibilitySettings');
          },
        ),
        const SizedBox(height: 8),
        _buildPermissionCard(
          'Display Over Other Apps',
          _permissions['overlay'] ?? false,
          'Required for blocking overlays',
          () async {
            await _channel.invokeMethod('requestOverlay');
          },
        ),
        const SizedBox(height: 8),
        _buildPermissionCard(
          'Device Admin',
          _permissions['deviceAdmin'] ?? false,
          'Optional: Enhanced uninstall protection',
          () async {
            await _channel.invokeMethod('enableDeviceAdmin');
          },
        ),
      ],
    );
  }
  
  Widget _buildPermissionCard(
    String title,
    bool isGranted,
    String description,
    VoidCallback onFix,
  ) {
    return ModernCard(
      child: ListTile(
        leading: Icon(
          isGranted ? Icons.check_circle : Icons.cancel,
          color: isGranted ? AppColors.successGreen : AppColors.dangerRed,
          size: 32,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          description,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: isGranted
            ? null
            : TextButton(
                onPressed: onFix,
                child: const Text('Fix', style: TextStyle(color: AppColors.primaryBlue)),
              ),
      ),
    );
  }
  
  Widget _buildBatteryOptimization() {
    final instructions = _manufacturerInfo['instructions'] ?? 'No specific instructions available.';
    
    return ModernCard(
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
                  size: 24,
                ),
                const SizedBox(width: 12),
                const Text(
                  'Battery Optimization',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _batteryOptimized
                    ? AppColors.successGreen.withValues(alpha:0.1)
                    : AppColors.warningOrange.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _batteryOptimized
                      ? AppColors.successGreen.withValues(alpha:0.3)
                      : AppColors.warningOrange.withValues(alpha:0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _batteryOptimized
                        ? '✅ Battery optimization is disabled (Good!)'
                        : '⚠️ Battery optimization is enabled',
                    style: TextStyle(
                      color: _batteryOptimized ? AppColors.successGreen : AppColors.warningOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_batteryOptimized) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Your device might kill the commitment monitoring service. Follow these steps:',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      instructions,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        text: 'Open Battery Settings',
                        icon: Icons.battery_saver,
                        gradient: AppColors.warningGradient,
                        onPressed: () async {
                          await _channel.invokeMethod('openManufacturerBatterySettings');
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
