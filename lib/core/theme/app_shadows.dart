import 'package:flutter/material.dart';

class AppShadows {
  // Shadow Elevation System
  static const List<BoxShadow> level1 = [
    BoxShadow(
      color: Color(0x0D000000), // rgba(0,0,0,0.05)
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> level2 = [
    BoxShadow(
      color: Color(0x14000000), // rgba(0,0,0,0.08)
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> level3 = [
    BoxShadow(
      color: Color(0x1F000000), // rgba(0,0,0,0.12)
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> level4 = [
    BoxShadow(
      color: Color(0x29000000), // rgba(0,0,0,0.16)
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> level5 = [
    BoxShadow(
      color: Color(0x33000000), // rgba(0,0,0,0.20)
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];
}