import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/gradient_button.dart';
import '../../app_blocking/services/installed_apps_service.dart';
import '../providers/app_blocking_provider_v2.dart';

class AppSelectionScreenV2 extends StatefulWidget {
  final bool isQuickMode;

  const AppSelectionScreenV2({super.key, this.isQuickMode = false});

  @override
  State<AppSelectionScreenV2> createState() => _AppSelectionScreenV2State();
}

class _AppSelectionScreenV2State extends State<AppSelectionScreenV2> {
  final Set<String> _selectedApps = {};
  int _durationMinutes = 60;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isQuickMode ? 'Quick Block' : 'Select Apps',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
      body: Column(
        children: [
          // 1. Duration Selector (if quick mode)
          if (widget.isQuickMode) _buildDurationSelector(),

          // 2. Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
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

          // 3. App List
          Expanded(
            child: Consumer<AppBlockingProviderV2>(
              builder: (context, provider, _) {
                final blockedPackages = provider.activeSessions.map((s) => s.appPackage).toSet();
                
                final apps = provider.installedApps.where((app) {
                  // Filter by search query
                  final matchesSearch = app.name.toLowerCase().contains(_searchQuery) ||
                         app.packageName.toLowerCase().contains(_searchQuery);
                  
                  // Filter out already blocked apps
                  final isNotBlocked = !blockedPackages.contains(app.packageName);
                  
                  return matchesSearch && isNotBlocked;
                }).toList();

                if (apps.isEmpty) {
                  return const Center(child: Text('No apps found', style: TextStyle(color: AppColors.textSecondary)));
                }

                return ListView.builder(
                  itemCount: apps.length,
                  itemBuilder: (context, index) {
                    final app = apps[index];
                    final isSelected = _selectedApps.contains(app.packageName);
                    
                    return ListTile(
                      leading: FutureBuilder<Uint8List?>(
                        future: InstalledAppsService().getAppIcon(app.packageName),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                            return Image.memory(snapshot.data!, width: 40, height: 40);
                          }
                          return const Icon(Icons.android, color: AppColors.textSecondary, size: 40);
                        },
                      ),
                      title: Text(app.name, style: const TextStyle(color: AppColors.textPrimary)),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: AppColors.primaryBlue,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedApps.add(app.packageName);
                            } else {
                              _selectedApps.remove(app.packageName);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedApps.remove(app.packageName);
                          } else {
                            _selectedApps.add(app.packageName);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          // 4. Action Button
          if (_selectedApps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                text: 'Block ${_selectedApps.length} Apps',
                gradient: AppColors.dangerGradient,
                onPressed: _blockSelectedApps,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [15, 30, 60, 120, 180].map((min) {
          final isSelected = _durationMinutes == min;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${min}m'),
              selected: isSelected,
              onSelected: (val) => setState(() => _durationMinutes = min),
              selectedColor: AppColors.primaryBlue,
              backgroundColor: AppColors.surfaceDark,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _blockSelectedApps() async {
    // If not in quick mode (or even if in quick mode, user might want custom time),
    // show a duration picker dialog.
    
    final provider = context.read<AppBlockingProviderV2>();
    int? selectedDuration = _durationMinutes;

    if (!widget.isQuickMode) {
      selectedDuration = await showDialog<int>(
        context: context,
        builder: (context) => _DurationPickerDialog(initialDuration: _durationMinutes),
      );
    }

    if (selectedDuration == null) return; // User cancelled


    
    for (final pkg in _selectedApps) {
      await provider.blockApp(pkg, selectedDuration);
    }
    
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          Future.delayed(const Duration(seconds: 2), () {
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          });
          return Dialog(
            backgroundColor: AppColors.cardDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/animations/checked.json',
                    width: 150,
                    height: 150,
                    repeat: false,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Apps Blocked!',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_selectedApps.length} apps blocked for $selectedDuration mins',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        },
      );
      
      // Wait a moment for animation to finish if needed, or just pop
      // The dialog is blocking, so we can just pop it after a delay or let user tap?
      // User requested "show successfully app is blocked", usually auto-dismiss is nice.
      // Let's auto-dismiss after 2 seconds.
    }
    
    if (mounted) {
      Navigator.pop(context); // Pop the screen
    }
  }
}

class _DurationPickerDialog extends StatefulWidget {
  final int initialDuration;

  const _DurationPickerDialog({required this.initialDuration});

  @override
  State<_DurationPickerDialog> createState() => _DurationPickerDialogState();
}

class _DurationPickerDialogState extends State<_DurationPickerDialog> {
  late int _selectedDuration;
  final TextEditingController _customController = TextEditingController();
  bool _isCustom = false;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.initialDuration;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.cardDark,
      title: const Text('Select Duration', style: TextStyle(color: AppColors.textPrimary)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [15, 30, 45, 60, 120].map((min) {
              final isSelected = !_isCustom && _selectedDuration == min;
              return ChoiceChip(
                label: Text('${min}m'),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    _isCustom = false;
                    _selectedDuration = min;
                  });
                },
                selectedColor: AppColors.primaryBlue,
                backgroundColor: AppColors.surfaceDark,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _customController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Custom Duration (minutes)',
              labelStyle: const TextStyle(color: AppColors.textSecondary),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border.withValues(alpha:0.3)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryBlue),
              ),
            ),
            onChanged: (val) {
              setState(() {
                _isCustom = true;
                _selectedDuration = int.tryParse(val) ?? 60;
              });
            },
            onTap: () => setState(() => _isCustom = true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
        ),
        SizedBox(
          width: 100,
          height: 40,
          child: GradientButton(
            text: 'Block',
            onPressed: () => Navigator.pop(context, _selectedDuration),
          ),
        ),
      ],
    );
  }
}
