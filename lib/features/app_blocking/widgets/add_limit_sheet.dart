import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import '../models/app_usage_limit.dart';
import '../../../core/theme/app_colors.dart';

class AddLimitSheet extends StatefulWidget {
  final List<AppInfo> availableApps;
  final List<AppUsageLimit> existingLimits;
  final Function(String packageName, String appName, int limitMinutes, int durationDays, bool enableCommitment, {int? maxLaunches}) onLimitAdded;

  const AddLimitSheet({
    super.key,
    required this.availableApps,
    required this.existingLimits,
    required this.onLimitAdded,
  });

  @override
  State<AddLimitSheet> createState() => _AddLimitSheetState();
}

class _AddLimitSheetState extends State<AddLimitSheet> {
  AppInfo? _selectedApp;
  int _limitMinutes = 60;
  int _durationDays = -1; // -1 means indefinite
  bool _enableCommitment = false;
  bool _enableLaunchLimit = false;
  int _maxLaunches = 10;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final existingPackages = widget.existingLimits.map((l) => l.packageName).toSet();
    final filteredApps = widget.availableApps
        .where((app) => 
            !existingPackages.contains(app.packageName) &&
            (app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             app.packageName.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header
          Row(
            children: [
              const Text(
                'Add Usage Limit',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar
          TextField(
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
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),

          // Selected App
          if (_selectedApp != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.primaryBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedApp!.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedApp = null),
                    child: const Text('Change'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Time Limit Selector
            const Text(
              'Daily Time Limit',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [15, 30, 60, 90, 120, 180].map((minutes) {
                final isSelected = _limitMinutes == minutes;
                return ChoiceChip(
                  label: Text('${minutes}m'),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _limitMinutes = minutes),
                  selectedColor: AppColors.primaryBlue,
                  backgroundColor: AppColors.surfaceDark,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Launch Limit Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _enableLaunchLimit 
                    ? AppColors.primaryBlue.withValues(alpha: 0.1)
                    : AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _enableLaunchLimit 
                      ? AppColors.primaryBlue.withValues(alpha: 0.3)
                      : AppColors.border.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.touch_app,
                        color: _enableLaunchLimit ? AppColors.primaryBlue : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Daily Launch Limit',
                              style: TextStyle(
                                color: _enableLaunchLimit ? AppColors.primaryBlue : AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Limit how many times app can be opened',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableLaunchLimit,
                        onChanged: (value) => setState(() => _enableLaunchLimit = value),
                        activeColor: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                  if (_enableLaunchLimit) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Maximum Opens Per Day',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [5, 10, 15, 20, 25, 30].map((launches) {
                        final isSelected = _maxLaunches == launches;
                        return ChoiceChip(
                          label: Text('$launches'),
                          selected: isSelected,
                          onSelected: (selected) => setState(() => _maxLaunches = launches),
                          selectedColor: AppColors.primaryBlue,
                          backgroundColor: AppColors.surfaceDark,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.primaryBlue),
                          const SizedBox(width: 8),
                          Text(
                            'App can be opened $_maxLaunches times per day',
                            style: const TextStyle(
                              color: AppColors.primaryBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Duration Selector
            const Text(
              'Limit Duration',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                {'label': 'Indefinite', 'days': -1},
                {'label': '1 Day', 'days': 1},
                {'label': '3 Days', 'days': 3},
                {'label': '7 Days', 'days': 7},
                {'label': '14 Days', 'days': 14},
                {'label': '30 Days', 'days': 30},
              ].map((option) {
                final days = option['days'] as int;
                final label = option['label'] as String;
                final isSelected = _durationDays == days;
                return ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) => setState(() => _durationDays = days),
                  selectedColor: AppColors.warningOrange,
                  backgroundColor: AppColors.surfaceDark,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Commitment Mode Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _enableCommitment 
                    ? AppColors.warningOrange.withValues(alpha: 0.1)
                    : AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _enableCommitment 
                      ? AppColors.warningOrange.withValues(alpha: 0.3)
                      : AppColors.border.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: _enableCommitment ? AppColors.warningOrange : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Commitment Mode',
                          style: TextStyle(
                            color: _enableCommitment ? AppColors.warningOrange : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cannot remove limit for ${_durationDays == -1 ? "any" : "$_durationDays"} day${_durationDays == 1 ? "" : "s"}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _enableCommitment,
                    onChanged: (value) => setState(() => _enableCommitment = value),
                    activeColor: AppColors.warningOrange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Add Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (_selectedApp != null) {
                    widget.onLimitAdded(
                      _selectedApp!.packageName,
                      _selectedApp!.name,
                      _limitMinutes,
                      _durationDays,
                      _enableCommitment,
                      maxLaunches: _enableLaunchLimit ? _maxLaunches : null,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add Limit',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ] else ...[
            // App List
            const Text(
              'Select an app',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: filteredApps.isEmpty
                  ? const Center(
                      child: Text(
                        'No apps available',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = filteredApps[index];
                        return ListTile(
                          leading: app.icon != null && app.icon!.isNotEmpty
                              ? Image.memory(app.icon!, width: 40, height: 40)
                              : const Icon(Icons.apps, color: AppColors.textSecondary),
                          title: Text(
                            app.name,
                            style: const TextStyle(color: AppColors.textPrimary),
                          ),
                          subtitle: Text(
                            app.packageName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => setState(() => _selectedApp = app),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}
