import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:installed_apps/app_info.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/gradient_button.dart';
import '../providers/app_blocking_provider_v2.dart';
import 'app_selection_screen_v2.dart';
import 'permission_setup_screen_v2.dart';
import '../../app_blocking/screens/app_usage_limiter_screen.dart'; // Import legacy limiter screen

class AppBlockingScreenV2 extends StatefulWidget {
  const AppBlockingScreenV2({Key? key}) : super(key: key);

  @override
  State<AppBlockingScreenV2> createState() => _AppBlockingScreenV2State();
}

class _AppBlockingScreenV2State extends State<AppBlockingScreenV2> {
  int _selectedMode = 0; // 0: Focus Mode, 1: Usage Limiter
  DateTime? _protectionLockEndTime;
  bool _isProtectionActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppBlockingProviderV2>().initialize();
      _checkProtectionStatus();
    });
  }
  
  Future<void> _checkProtectionStatus() async {
    try {
      final channel = const MethodChannel('app_blocking');
      final timestamp = await channel.invokeMethod<int>('getUninstallLock');
      if (timestamp != null && timestamp > 0) {
        final endTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
        if (endTime.isAfter(DateTime.now())) {
          setState(() {
            _protectionLockEndTime = endTime;
            _isProtectionActive = true;
          });
        }
      }
    } catch (e) {
      print('Error checking protection status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('App Control', style: TextStyle(color: AppColors.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () => context.read<AppBlockingProviderV2>().refreshData(),
          ),
        ],
      ),
      body: Consumer<AppBlockingProviderV2>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: provider.refreshData,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Permission Warning (Non-blocking)
                  if (provider.hasPermissionIssues)
                    _buildPermissionWarning(context, provider.missingPermissions),

                  const SizedBox(height: 8),

                  // 2. Mode Toggle
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildModeButton(0, 'Focus Mode', Icons.shield),
                          const SizedBox(width: 8),
                          _buildModeButton(1, 'Usage Limiter', Icons.timer),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // 3. Content based on mode
                  if (_selectedMode == 0)
                    _buildFocusMode(context, provider)
                  else
                    _buildLimiterMode(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeButton(int index, String label, IconData icon) {
    final isSelected = _selectedMode == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMode = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusMode(BuildContext context, AppBlockingProviderV2 provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStatusCard(provider),
        const SizedBox(height: 24),
        _buildProtectionLock(context),
        const SizedBox(height: 24),
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildQuickActions(context),
        const SizedBox(height: 24),
        const Text(
          'Active Blocks',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildActiveBlocksList(provider),
      ],
    );
  }

  Widget _buildLimiterMode(BuildContext context) {
    // Reuse the existing Limiter Screen UI logic, but embedded
    // For now, we'll wrap the existing screen in a Container
    // Ideally, we should refactor AppUsageLimiterScreen to be a widget we can embed
    // But for speed, we can just instantiate it here if it supports it, or rebuild the UI
    // Since AppUsageLimiterScreen is a Scaffold, we can't embed it directly.
    // We will show a placeholder that links to it for now, or better yet,
    // we should refactor AppUsageLimiterScreen to be a widget.
    
    // For this iteration, let's provide a clean entry point
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.warningOrange.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.timer_outlined, size: 48, color: AppColors.warningOrange),
              const SizedBox(height: 16),
              const Text(
                'Daily Usage Limits',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Set daily time allowances for your apps. Once the limit is reached, the app is blocked for the rest of the day.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: GradientButton(
                  text: 'Manage Limits',
                  icon: Icons.settings,
                  gradient: AppColors.warningGradient,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AppUsageLimiterScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionWarning(BuildContext context, List<String> missing) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warningOrange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warningOrange),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Permissions Required',
                  style: TextStyle(
                    color: AppColors.warningOrange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Some features may not work. Missing: ${missing.join(", ")}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.warningOrange),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PermissionSetupScreenV2()),
                );
              },
              child: const Text('Fix Permissions', style: TextStyle(color: AppColors.warningOrange)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(AppBlockingProviderV2 provider) {
    final activeCount = provider.activeSessions.length;
    final isBlocking = activeCount > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isBlocking 
              ? [AppColors.primaryBlue.withOpacity(0.2), AppColors.primaryBlue.withOpacity(0.1)]
              : [AppColors.surfaceDark, AppColors.surfaceDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isBlocking ? AppColors.primaryBlue.withOpacity(0.3) : AppColors.border.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isBlocking ? AppColors.primaryBlue : AppColors.surfaceDark,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isBlocking ? Icons.shield : Icons.shield_outlined,
              color: isBlocking ? Colors.white : AppColors.textSecondary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isBlocking ? 'Focus Mode Active' : 'Focus Mode Idle',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isBlocking 
                      ? '$activeCount apps currently blocked' 
                      : 'No apps are currently blocked',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionCard(
            icon: Icons.flash_on,
            label: 'Quick Block',
            color: AppColors.primaryBlue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppSelectionScreenV2(isQuickMode: true)),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionCard(
            icon: Icons.security,
            label: 'Strict Mode',
            color: AppColors.dangerRed,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppSelectionScreenV2(isQuickMode: false)),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ModernCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBlocksList(AppBlockingProviderV2 provider) {
    if (provider.activeSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline, size: 48, color: AppColors.textSecondary.withOpacity(0.3)),
              const SizedBox(height: 16),
              const Text(
                'All clear! No apps blocked.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.activeSessions.length,
      itemBuilder: (context, index) {
        final session = provider.activeSessions[index];
        final appInfo = provider.getAppInfo(session.appPackage);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: ModernCard(
            child: ListTile(
              leading: appInfo != null && appInfo.icon != null
                  ? Image.memory(appInfo.icon!, width: 40, height: 40)
                  : const Icon(Icons.block, color: AppColors.dangerRed, size: 40),
              title: Text(
                appInfo?.name ?? session.appPackage,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${session.remainingTime.inMinutes}m remaining',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.lock, color: AppColors.textSecondary, size: 20), // Strict Mode
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildProtectionLock(BuildContext context) {
    final remainingTime = _isProtectionActive && _protectionLockEndTime != null
        ? _protectionLockEndTime!.difference(DateTime.now())
        : Duration.zero;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isProtectionActive
              ? [AppColors.dangerRed.withOpacity(0.2), AppColors.dangerRed.withOpacity(0.1)]
              : [AppColors.surfaceDark, AppColors.surfaceDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isProtectionActive 
              ? AppColors.dangerRed.withOpacity(0.3) 
              : AppColors.border.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isProtectionActive 
                      ? AppColors.dangerRed 
                      : AppColors.surfaceDark,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isProtectionActive ? Icons.lock : Icons.lock_open,
                  color: _isProtectionActive ? Colors.white : AppColors.textSecondary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isProtectionActive ? 'Commitment Active' : 'Commitment Mode',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isProtectionActive
                          ? 'Expires in ${remainingTime.inHours}h ${remainingTime.inMinutes.remainder(60)}m'
                          : 'Lock your focus settings for set duration',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!_isProtectionActive) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildLockDurationChip('1 Hour', 1),
                _buildLockDurationChip('12 Hours', 12),
                _buildLockDurationChip('24 Hours', 24),
                _buildLockDurationChip('7 Days', 24 * 7),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildLockDurationChip(String label, int hours) {
    return InkWell(
      onTap: () => _activateProtectionLock(hours),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.dangerRed.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_clock, size: 16, color: AppColors.dangerRed),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _activateProtectionLock(int hours) async {
    try {
      final endTime = DateTime.now().add(Duration(hours: hours));
      final channel = const MethodChannel('app_blocking');
      await channel.invokeMethod('setUninstallLock', {
        'timestamp': endTime.millisecondsSinceEpoch,
      });
      
      setState(() {
        _protectionLockEndTime = endTime;
        _isProtectionActive = true;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔒 Commitment activated for $hours hour${hours > 1 ? 's' : ''}'),
            backgroundColor: AppColors.dangerRed,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to activate protection: $e'),
            backgroundColor: AppColors.dangerRed,
          ),
        );
      }
    }
  }
}
