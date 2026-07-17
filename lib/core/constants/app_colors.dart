import 'package:flutter/material.dart';

class AppColors {
  // Ana arka plan — siyaha yakın, düz (gradyan/cam efekti yok)
  static const background = Color(0xFF08090C);
  static const cardBg = Color(0xFF16181E);
  static const cardBgLight = Color(0xFF1B1E26);
  static const hairline = Color(0xFF262A34);

  // Marka vurgusu — tek ve net (eski mor→camgöbeği gradyanının yerini aldı)
  static const accent = Color(0xFF3D7DFF);
  static const accentDark = Color(0xFF1E3A8A);

  // Durum renkleri
  static const green = Color(0xFF3DDC84);   // Gelir
  static const red = Color(0xFFF2685C);     // Gider
  static const orange = Color(0xFFF59E0B);  // Uyarı

  // Tip/kategori ayırt edici renkler — marka vurgusundan bağımsız;
  // birden fazla tip aynı ekranda yan yana göründüğünde (yatırım tipi,
  // kategori ikonu, grafik serisi) birbirinden ayrışsınlar diye.
  static const violet = Color(0xFF8B5CF6);
  static const cyan = Color(0xFF06B6D4);

  // Metin renkleri
  static const textPrimary = Color(0xFFF5F6F8);
  static const textSecondary = Color(0xFF9497A6);
  static const textMuted = Color(0xFF565A68);
}
