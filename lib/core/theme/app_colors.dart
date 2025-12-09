import 'package:flutter/material.dart';

class AppColors {
  // ========================================
  // MODERN DARK PALETTE
  // ========================================
  
  // Background Layers (Clear Hierarchy)
  static const Color backgroundDark = Color(0xFF0A0A0F); // Deep navy-black (base)
  static const Color surfaceDark = Color(0xFF16161F);     // Surface layer
  static const Color cardDark = Color(0xFF1E1E2E);        // Card layer
  static const Color cardHover = Color(0xFF252535);       // Hover state
  
  // Accent Colors (High Contrast)
  static const Color primaryBlue = Color(0xFF3B82F6);     // Focus Mode
  static const Color successGreen = Color(0xFF10B981);    // Active/Success
  static const Color warningOrange = Color(0xFFF59E0B);   // Commitment Mode (Amber)
  static const Color dangerRed = Color(0xFFEF4444);       // Blocked/Danger
  
  // Accent Variants (Darker shades)
  static const Color focusBlueDim = Color(0xFF2563EB);
  static const Color successGreenDim = Color(0xFF059669);
  static const Color commitmentGoldDim = Color(0xFFD97706);
  static const Color dangerRedDim = Color(0xFFDC2626);
  
  // Text Colors (Optimal Contrast)
  static const Color textPrimary = Color(0xFFF1F5F9);     // Almost white
  static const Color textSecondary = Color(0xFF94A3B8);   // Slate gray
  static const Color textTertiary = Color(0xFF64748B);    // Muted slate
  
  // Borders & Dividers
  static const Color border = Color(0xFF2D2D3D);          // Subtle border
  static const Color borderLight = Color(0xFF2D2D3D);
  static const Color borderMedium = Color(0xFF3D3D4D);
  static const Color borderStrong = Color(0xFF4D4D5D);

  // Legacy Aliases (for compatibility)
  static const Color primary = primaryBlue;
  static const Color secondary = successGreen;
  static const Color accent = warningOrange;

  // Rank Colors (Modern theme)
  static const Color rank1 = Color(0xFFFFD700);           // Gold
  static const Color rank2 = Color(0xFFC0C0C0);           // Silver
  static const Color rank3 = Color(0xFFCD7F32);           // Bronze
  static const Color top10 = Color(0xFF3B82F6);           // Blue
  static const Color top50 = Color(0xFF10B981);           // Green
  static const Color others = Color(0xFF64748B);          // Gray

  // Gradients (as LinearGradient)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Gradients (as List<Color> for compatibility)
  static const List<Color> cardGradient = [Color(0xFF1E1E2E), Color(0xFF16161F)];
  static const List<Color> activeGradient = [Color(0xFF3B82F6), Color(0xFF2563EB)];
  static const List<Color> successGradientColors = [Color(0xFF10B981), Color(0xFF059669)];
  static const List<Color> warningGradientColors = [Color(0xFFF59E0B), Color(0xFFD97706)];
  static const List<Color> dangerGradientColors = [Color(0xFFEF4444), Color(0xFFDC2626)];

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF3B82F6), // Blue
    Color(0xFF10B981), // Green
    Color(0xFFF59E0B), // Amber
    Color(0xFFEF4444), // Red
    Color(0xFF8B5CF6), // Purple
    Color(0xFF06B6D4), // Cyan
  ];

  // Status Colors
  static const Color statusOnline = Color(0xFF10B981);
  static const Color statusAway = Color(0xFFF59E0B);
  static const Color statusOffline = Color(0xFF64748B);
  static const Color statusBusy = Color(0xFFEF4444);
}