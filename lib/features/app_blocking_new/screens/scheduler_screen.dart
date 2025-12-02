import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../providers/app_blocking_provider_v2.dart';
import '../models/app_schedule.dart';
import '../../app_blocking/services/installed_apps_service.dart';
import 'dart:typed_data';

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Block Scheduler', style: TextStyle(color: AppColors.textPrimary)),
      ),
      body: Column(
        children: [
          // Info Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule, color: AppColors.primaryBlue),
                  SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Set "Allowed Times" for your apps. Outside these hours, they will be blocked.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search apps...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceDark,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          const SizedBox(height: 16),

          // App List
          Expanded(
            child: Consumer<AppBlockingProviderV2>(
              builder: (context, provider, _) {
                final apps = provider.installedApps.where((app) {
                  return app.name.toLowerCase().contains(_searchQuery) ||
                         app.packageName.toLowerCase().contains(_searchQuery);
                }).toList();

                if (apps.isEmpty) {
                  return const Center(child: Text('No apps found', style: TextStyle(color: AppColors.textSecondary)));
                }

                return ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final schedule = provider.getSchedule(app.packageName);
                    
                    return ListTile(
                      leading: FutureBuilder<Uint8List?>(
                        future: InstalledAppsService().getAppIcon(app.packageName),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return Image.memory(snapshot.data!, width: 40, height: 40);
                          }
                          return const Icon(Icons.android, color: AppColors.textSecondary, size: 40);
                        },
                      ),
                      title: Text(app.name, style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: schedule != null
                          ? Text(
                              'Allowed: ${schedule.startTime.format(context)} - ${schedule.endTime.format(context)}',
                              style: const TextStyle(color: AppColors.primaryBlue),
                            )
                          : const Text('No schedule set', style: TextStyle(color: AppColors.textSecondary)),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: schedule != null ? AppColors.primaryBlue : AppColors.textSecondary,
                      ),
                      onTap: () => _showScheduleDialog(context, app.packageName, app.name, schedule),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog(BuildContext context, String packageName, String appName, AppSchedule? existingSchedule) {
    TimeOfDay start = existingSchedule?.startTime ?? const TimeOfDay(hour: 20, minute: 0);
    TimeOfDay end = existingSchedule?.endTime ?? const TimeOfDay(hour: 21, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.cardDark,
            title: Text('Schedule for $appName', style: const TextStyle(color: AppColors.textPrimary)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select ALLOWED time range:',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimeButton(context, 'Start', start, (val) => setState(() => start = val)),
                    const Text('-', style: TextStyle(color: AppColors.textPrimary)),
                    _buildTimeButton(context, 'End', end, (val) => setState(() => end = val)),
                  ],
                ),
              ],
            ),
            actions: [
              if (existingSchedule != null)
                TextButton(
                  onPressed: () async {
                    try {
                      await context.read<AppBlockingProviderV2>().deleteSchedule(packageName);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                        );
                      }
                    }
                  },
                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    final schedule = AppSchedule(
                      packageName: packageName,
                      appName: appName,
                      startHour: start.hour,
                      startMinute: start.minute,
                      endHour: end.hour,
                      endMinute: end.minute,
                    );
                    await context.read<AppBlockingProviderV2>().saveSchedule(schedule);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                      );
                    }
                  }
                },
                child: const Text('Save', style: TextStyle(color: AppColors.primaryBlue)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeButton(BuildContext context, String label, TimeOfDay time, Function(TimeOfDay) onSelect) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
              builder: (context, child) {
                return Theme(
                  data: ThemeData.dark().copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.primaryBlue,
                      onPrimary: Colors.white,
                      surface: AppColors.cardDark,
                      onSurface: AppColors.textPrimary,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) onSelect(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border.withOpacity(0.3)),
            ),
            child: Text(
              time.format(context),
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
