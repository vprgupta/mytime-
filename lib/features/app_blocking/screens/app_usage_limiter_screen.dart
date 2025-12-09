import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:installed_apps/app_info.dart';
import '../models/app_usage_limit.dart';
import '../services/app_usage_limiter_service.dart';
import '../services/installed_apps_service.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/add_limit_sheet.dart';

class AppUsageLimiterScreen extends StatefulWidget {
  final bool embeddable;
  
  const AppUsageLimiterScreen({super.key, this.embeddable = false});

  @override
  State<AppUsageLimiterScreen> createState() => _AppUsageLimiterScreenState();
}

class _AppUsageLimiterScreenState extends State<AppUsageLimiterScreen> {
  final AppUsageLimiterService _limiterService = AppUsageLimiterService();
  final InstalledAppsService _appsService = InstalledAppsService();
  List<AppUsageLimit> _limits = [];
  List<AppInfo> _availableApps = [];
  bool _isLoading = true;
  Map<String, Uint8List?> _appIcons = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    Future.delayed(const Duration(seconds: 30), _autoRefresh);
  }

  void _autoRefresh() {
    if (mounted) {
      _loadData();
      Future.delayed(const Duration(seconds: 30), _autoRefresh);
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _limiterService.initialize();
      _limits = _limiterService.getAllLimits();
      _availableApps = await _appsService.getUserApps();
      
      for (var limit in _limits) {
        if (!_appIcons.containsKey(limit.packageName)) {
          final icon = await _appsService.getAppIcon(limit.packageName);
          _appIcons[limit.packageName] = icon;
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Color _getProgressColor(AppUsageLimit limit) {
    if (limit.isBlocked) return AppColors.dangerRed;
    final progress = limit.usedMinutesToday / limit.currentLimitMinutes;
    if (progress >= 0.9) return AppColors.dangerRed;
    if (progress >= 0.7) return AppColors.warningOrange;
    return AppColors.successGreen;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddable) {
      return _buildBody();
    }
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Usage Limits', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primaryBlue),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLimitDialog,
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Limit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
    }
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCards(),
            const SizedBox(height: 16),
            // Add Limit Button (for embedded version)
            if (widget.embeddable)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _showAddLimitDialog,
                  icon: const Icon(Icons.add_circle_outline, size: 24),
                  label: const Text(
                    'Add Usage Limit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (_limits.isNotEmpty) ...[
              _buildSectionHeader('Active Limits', _limits.length),
              const SizedBox(height: 12),
              _buildLimitsList(),
            ] else
              _buildEmptyState(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final activeLimits = _limits.where((l) => l.isActive).length;
    final blockedApps = _limits.where((l) => l.isBlocked).length;
    final totalTimeSaved = _limits.fold<int>(0, (sum, limit) {
      if (limit.isBlocked) {
        return sum + (limit.currentLimitMinutes - limit.usedMinutesToday).abs();
      }
      return sum;
    });

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.timer_outlined,
            value: '$activeLimits',
            label: 'Active',
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.block,
            value: '$blockedApps',
            label: 'Blocked',
            color: AppColors.dangerRed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_down,
            value: '${totalTimeSaved}m',
            label: 'Saved',
            color: AppColors.successGreen,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLimitsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _limits.length,
      itemBuilder: (context, index) => _buildLimitCard(_limits[index]),
    );
  }

  Widget _buildLimitCard(AppUsageLimit limit) {
    final progress = (limit.usedMinutesToday / limit.currentLimitMinutes).clamp(0.0, 1.0);
    final progressColor = _getProgressColor(limit);
    final icon = _appIcons[limit.packageName];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: limit.isBlocked 
            ? Border.all(color: AppColors.dangerRed.withValues(alpha: 0.3), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // App Icon
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: icon != null && icon.isNotEmpty
                ? Image.memory(icon, width: 48, height: 48, fit: BoxFit.cover)
                : Container(
                    width: 48,
                    height: 48,
                    color: AppColors.surfaceDark,
                    child: Center(
                      child: Text(
                        limit.appName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          // App Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        limit.appName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (limit.isBlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.dangerRed,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'BLOCKED',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress Bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceDark,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${limit.usedMinutesToday}m / ${limit.currentLimitMinutes}m',
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Actions
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onPressed: () => _showLimitOptions(limit),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Lottie.asset(
              'assets/animations/empty_box.json',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16),
            const Text(
              'No usage limits set',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to limit an app',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLimitOptions(AppUsageLimit limit) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: AppColors.dangerRed),
              title: const Text('Remove Limit', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                _removeLimit(limit);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLimitDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardDark,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => AddLimitSheet(
          availableApps: _availableApps,
          existingLimits: _limits,
          onLimitAdded: (packageName, appName, limitMinutes, durationDays, enableCommitment) async {
            await _limiterService.setAppLimit(
              packageName, 
              appName, 
              limitMinutes,
              durationDays: durationDays,
              hasCommitment: enableCommitment,
            );
            _loadData();
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _removeLimit(AppUsageLimit limit) async {
    try {
      await _limiterService.removeAppLimit(limit.packageName);
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Limit removed for ${limit.appName}'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.dangerRed,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}