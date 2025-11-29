import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/modern_card.dart';
import '../../../core/widgets/status_pill.dart';

class ModernHeader extends StatelessWidget {
  final int activeCount;
  final int totalBlocked;
  final Duration totalSavedTime;
  final List<String> activeApps;

  const ModernHeader({
    super.key,
    required this.activeCount,
    required this.totalBlocked,
    required this.totalSavedTime,
    required this.activeApps,
  });

  @override
  Widget build(BuildContext context) {
    return ModernCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield,
                  color: AppColors.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeCount > 0 ? 'Focus Mode: ON' : 'Focus Mode: OFF',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$activeCount blocked • $totalBlocked apps • ${_formatDuration(totalSavedTime)} saved',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                text: activeCount > 0 ? 'ACTIVE' : 'IDLE',
                color: activeCount > 0 ? AppColors.successGreen : AppColors.textSecondary,
              ),
            ],
          ),
          if (activeCount > 0) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.block, color: AppColors.dangerRed, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BLOCKING: ${activeApps.join(', ')}',
                      style: const TextStyle(
                        color: AppColors.dangerRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}