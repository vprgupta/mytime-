import 'package:flutter/material.dart';

class AppColors {
  // Modern Primary Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningOrange = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFEF4444);

  // Dark Theme Colors
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color cardDark = Color(0xFF334155);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color border = Color(0xFF475569);

  // Legacy Colors (for compatibility)
  static const Color primary = primaryBlue;
  static const Color secondary = Color(0xFF7C3AED);
  static const Color accent = warningOrange;

  // Rank Colors
  static const Color rank1 = Color(0xFFFFD700);
  static const Color rank2 = Color(0xFFC0C0C0);
  static const Color rank3 = Color(0xFFCD7F32);
  static const Color top10 = Color(0xFF3B82F6);
  static const Color top50 = Color(0xFF6366F1);
  static const Color others = Color(0xFF64748B);

  // Status Colors
  static const Color online = successGreen;
  static const Color away = warningOrange;
  static const Color offline = Color(0xFF6B7280);

  // Background Gradients
  static const List<Color> globalGradient = [primaryBlue, Color(0xFF7C3AED)];
  static const List<Color> friendsGradient = [successGreen, primaryBlue];
  static const List<Color> groupsGradient = [Color(0xFF7C3AED), Color(0xFFEC4899)];
  static const List<Color> modernGradient = [backgroundDark, surfaceDark];

  // Modern Card Gradients
  static const List<Color> cardGradient = [cardDark, surfaceDark];
  static const List<Color> activeGradient = [primaryBlue, Color(0xFF3B82F6)];
  static const List<Color> successGradient = [successGreen, Color(0xFF059669)];
  static const List<Color> warningGradient = [warningOrange, Color(0xFFD97706)];
  static const List<Color> dangerGradient = [dangerRed, Color(0xFFDC2626)];

  // Legacy Support
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);
  static const Color cardShadow = Color(0x1A000000);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Get rank color based on position
  static Color getRankColor(int rank) {
    if (rank == 1) return rank1;
    if (rank == 2) return rank2;
    if (rank == 3) return rank3;
    if (rank <= 10) return top10;
    if (rank <= 50) return top50;
    return others;
  }

  // Get gradient for tab type
  static List<Color> getTabGradient(String tabType) {
    switch (tabType.toLowerCase()) {
      case 'global':
        return globalGradient;
      case 'friends':
        return friendsGradient;
      case 'groups':
        return groupsGradient;
      default:
        return globalGradient;
    }
  }
}