import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import '../models/app_usage_limit.dart';
import '../services/app_usage_limiter_service.dart';
import '../services/installed_apps_service.dart';
import '../../../core/widgets/app_card.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Usage Limits'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsSection(),
                Expanded(child: _buildLimitsList()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLimitDialog,
        child: const Icon(Icons.add),
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
            child: AppCard(
              child: Column(
                children: [
                  Text('$activeLimits', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const Text('Active Limits'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: AppCard(
              child: Column(
                children: [
                  Text('$blockedApps', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                  const Text('Blocked Today'),
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
      return const Center(child: Text('No usage limits set'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _limits.length,
      itemBuilder: (context, index) => _buildLimitCard(_limits[index]),
    );
  }

  Widget _buildLimitCard(AppUsageLimit limit) {
    final progress = limit.usedMinutesToday / limit.currentLimitMinutes;
    final progressColor = limit.isBlocked ? Colors.red : (progress > 0.8 ? Colors.orange : Colors.green);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(limit.appName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${limit.usedMinutesToday}/${limit.currentLimitMinutes} min'),
                    ],
                  ),
                ),
                if (limit.isBlocked)
                  const Icon(Icons.block, color: Colors.red)
                else
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeLimit(limit),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Day ${limit.consecutiveDays + 1}'),
                Text('${limit.remainingMinutes} min left'),
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
        onLimitAdded: (packageName, appName, minutes) async {
          await _limiterService.setAppLimit(packageName, appName, minutes);
          _loadData();
        },
      ),
    );
  }

  Future<void> _removeLimit(AppUsageLimit limit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Limit'),
        content: Text('Remove usage limit for ${limit.appName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
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
  final Function(String, String, int) onLimitAdded;

  const _AddLimitDialog({required this.availableApps, required this.onLimitAdded});

  @override
  State<_AddLimitDialog> createState() => _AddLimitDialogState();
}

class _AddLimitDialogState extends State<_AddLimitDialog> {
  String _searchQuery = '';
  int _limitMinutes = 60;
  final InstalledAppsService _appsService = InstalledAppsService();

  @override
  Widget build(BuildContext context) {
    final filteredApps = widget.availableApps.where((app) {
      return app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             app.packageName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 500, // Fixed height for the list
        child: Column(
          children: [
            const Text(
              'Add Usage Limit',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search Apps',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
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
                        return const Icon(Icons.android, size: 40);
                      },
                    ),
                    title: Text(app.name ?? app.packageName),
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
      builder: (context) => AlertDialog(
        title: Text('Set Limit for ${app.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Daily Limit (minutes)'),
              keyboardType: TextInputType.number,
              initialValue: _limitMinutes.toString(),
              onChanged: (value) => _limitMinutes = int.tryParse(value) ?? 60,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              widget.onLimitAdded(app.packageName, app.name ?? app.packageName, _limitMinutes);
              Navigator.pop(context); // Close limit dialog
              Navigator.pop(context); // Close app list dialog
            },
            child: const Text('Set Limit'),
          ),
        ],
      ),
    );
  }
}