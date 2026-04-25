import 'package:flutter/material.dart';

class AppColors {
  // Ana arka plan
  static const background = Color(0xFF0D1117);
  static const cardBg = Color(0xFF161B22);
  static const cardBgLight = Color(0xFF1C2333);

  // Accent renkler
  static const purple = Color(0xFF7C3AED);
  static const cyan = Color(0xFF06B6D4);
  static const purpleLight = Color(0xFF8B5CF6);

  // Durum renkleri
  static const green = Color(0xFF10B981);   // Gelir
  static const red = Color(0xFFEF4444);     // Gider
  static const orange = Color(0xFFF59E0B);  // Uyarı
  static const pink = Color(0xFFEC4899);    // Eğlence

  // Metin renkleri
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFF8B949E);
  static const textMuted = Color(0xFF484F58);

  // Gradient
  static const gradientPurpleCyan = LinearGradient(
    colors: [purple, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientPurple = LinearGradient(
    colors: [purple, purpleLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
