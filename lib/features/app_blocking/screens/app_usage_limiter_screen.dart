import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import '../models/app_usage_limit.dart';
import '../services/app_usage_limiter_service.dart';
import '../services/installed_apps_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/gradient_button.dart';

class AppUsageLimiterScreen extends StatefulWidget {
  const AppUsageLimiterScreen({super.key});

  @override
  State<AppUsageLimiterScreen> createState() => _AppUsageLimiterScreenState();
}

class _AppUsageLimiterScreenState extends State<AppUsageLimiterScreen> {
  final AppUsageLimiterService _limiterService = AppUsageLimiterService();
  final InstalledAppsService _appsService = InstalledAppsService();
  List<AppUsageLimit> _limits = [];
  List<AppInfo> _availableApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _limiterService.initialize();
      _limits = _limiterService.getAllLimits();
      _availableApps = await _appsService.getInstalledApps();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('App Usage Limits', style: TextStyle(color: AppColors.textPrimary)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue))
          : Column(
              children: [
                _buildStatsSection(),
                Expanded(child: _buildLimitsList()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLimitDialog,
        backgroundColor: AppColors.primaryBlue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildStatsSection() {
    final activeLimits = _limits.where((l) => l.isActive).length;
    final blockedApps = _limits.where((l) => l.isBlocked).length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ModernCard(
              child: Column(
                children: [
                  Text('$activeLimits', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const Text('Active Limits', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ModernCard(
              child: Column(
                children: [
                  Text('$blockedApps', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.dangerRed)),
                  const Text('Blocked Today', style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitsList() {
    if (_limits.isEmpty) {
      return const Center(child: Text('No usage limits set', style: TextStyle(color: AppColors.textSecondary)));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _limits.length,
      itemBuilder: (context, index) => _buildLimitCard(_limits[index]),
    );
  }

  Widget _buildLimitCard(AppUsageLimit limit) {
    final progress = limit.usedMinutesToday / limit.currentLimitMinutes;
    final progressColor = limit.isBlocked ? AppColors.dangerRed : (progress > 0.8 ? AppColors.warningOrange : AppColors.successGreen);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ModernCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(limit.appName, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text('${limit.usedMinutesToday}/${limit.currentLimitMinutes} min', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (limit.isBlocked)
                  const Icon(Icons.block, color: AppColors.dangerRed)
                else
                  IconButton(
                    icon: const Icon(Icons.delete, color: AppColors.textSecondary),
                    onPressed: () => _removeLimit(limit),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: AppColors.surfaceDark,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Day ${limit.consecutiveDays + 1}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text('${limit.remainingMinutes} min left', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddLimitDialog(
        availableApps: _availableApps,
        onLimitAdded: (packageName, appName, minutes, durationDays) async {
          await _limiterService.setAppLimit(packageName, appName, minutes, durationDays: durationDays);
          _loadData();
        },
      ),
    );
  }

  Future<void> _removeLimit(AppUsageLimit limit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        title: const Text('Remove Limit', style: TextStyle(color: AppColors.textPrimary)),
        content: Text('Remove usage limit for ${limit.appName}?', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: AppColors.dangerRed))),
        ],
      ),
    );

    if (confirm == true) {
      await _limiterService.removeAppLimit(limit.packageName);
      _loadData();
    }
  }
}

class _AddLimitDialog extends StatefulWidget {
  final List<AppInfo> availableApps;
  final Function(String, String, int, int) onLimitAdded;

  const _AddLimitDialog({required this.availableApps, required this.onLimitAdded});

  @override
  State<_AddLimitDialog> createState() => _AddLimitDialogState();
}

class _AddLimitDialogState extends State<_AddLimitDialog> {
  String _searchQuery = '';
  int _limitMinutes = 60;
  int _durationDays = -1; // -1 for indefinite
  final InstalledAppsService _appsService = InstalledAppsService();

  @override
  Widget build(BuildContext context) {
    final filteredApps = widget.availableApps.where((app) {
      return app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      backgroundColor: AppColors.cardDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 500,
        child: Column(
          children: [
            const Text(
              'Add Usage Limit',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            TextField(
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Search Apps',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.border.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.primaryBlue),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: filteredApps.length,
                itemBuilder: (context, index) {
                  final app = filteredApps[index];
                  return ListTile(
                    leading: FutureBuilder<Uint8List?>(
                      future: _appsService.getAppIcon(app.packageName),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                          return Image.memory(snapshot.data!, width: 40, height: 40);
                        }
                        return const Icon(Icons.android, size: 40, color: AppColors.textSecondary);
                      },
                    ),
                    title: Text(app.name ?? app.packageName, style: const TextStyle(color: AppColors.textPrimary)),
                    onTap: () => _showLimitSetting(app),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLimitSetting(AppInfo app) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: Text('Set Limit for ${app.name}', style: const TextStyle(color: AppColors.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Daily Limit (minutes)',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryBlue)),
                  ),
                  keyboardType: TextInputType.number,
                  initialValue: _limitMinutes.toString(),
                  onChanged: (value) => _limitMinutes = int.tryParse(value) ?? 60,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _durationDays,
                  dropdownColor: AppColors.cardDark,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Duration',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.textSecondary)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryBlue)),
                  ),
                  items: const [
                    DropdownMenuItem(value: -1, child: Text('Indefinite')),
                    DropdownMenuItem(value: 1, child: Text('1 Day')),
                    DropdownMenuItem(value: 3, child: Text('3 Days')),
                    DropdownMenuItem(value: 7, child: Text('7 Days')),
                    DropdownMenuItem(value: 30, child: Text('30 Days')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _durationDays = value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
                onPressed: () {
                  widget.onLimitAdded(app.packageName, app.name ?? app.packageName, _limitMinutes, _durationDays);
                  Navigator.pop(context); // Close limit dialog
                  Navigator.pop(context); // Close app list dialog
                },
                child: const Text('Set Limit', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }
}