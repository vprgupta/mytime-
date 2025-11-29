import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_card.dart';

class QuickActionsHub extends StatelessWidget {
  final VoidCallback onQuickBlock;
  final VoidCallback onSelectApps;
  final VoidCallback onScheduleBlock;
  final VoidCallback onAnalytics;
  final VoidCallback onFocusMode;
  final VoidCallback onGoals;

  const QuickActionsHub({
    super.key,
    required this.onQuickBlock,
    required this.onSelectApps,
    required this.onScheduleBlock,
    required this.onAnalytics,
    required this.onFocusMode,
    required this.onGoals,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.flash_on,
                title: 'Quick\nBlock',
                color: AppColors.primaryBlue,
                onTap: onQuickBlock,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.apps,
                title: 'Select\nApps',
                color: AppColors.successGreen,
                onTap: onSelectApps,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.schedule,
                title: 'Schedule\nBlock',
                color: AppColors.warningOrange,
                onTap: onScheduleBlock,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.analytics,
                title: 'Analytics',
                color: AppColors.secondary,
                onTap: onAnalytics,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.track_changes,
                title: 'Focus\nMode',
                color: AppColors.primaryBlue,
                onTap: onFocusMode,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                icon: Icons.emoji_events,
                title: 'Goals',
                color: AppColors.warningOrange,
                onTap: onGoals,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ModernCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}