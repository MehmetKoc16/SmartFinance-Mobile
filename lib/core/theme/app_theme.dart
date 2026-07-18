import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_tokens.dart';

/// Plus Jakarta Sans — başlıklar ve büyük rakamlar için (bkz. design_handoff_smartfinance).
/// Gövde metni Inter (tema textTheme'i üzerinden), bu yalnızca vurgulu yerlerde kullanılır.
TextStyle jakarta({
  required double fontSize,
  FontWeight fontWeight = FontWeight.w600,
  Color? color,
  double? letterSpacing,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );

class AppTheme {
  static ThemeData _build(AppTokens t, Brightness brightness) {
    final base = GoogleFonts.interTextTheme(
      brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: t.bg,
      extensions: [t],

      colorScheme: (brightness == Brightness.dark
              ? const ColorScheme.dark()
              : const ColorScheme.light())
          .copyWith(
        primary: t.brand,
        secondary: t.brand,
        surface: t.card,
        error: t.red,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: t.bg,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.text),
        iconTheme: IconThemeData(color: t.text),
      ),

      textTheme: base.apply(bodyColor: t.text, displayColor: t.text),

      cardTheme: CardThemeData(
        color: t.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: t.border, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: t.brand, width: 1.5),
        ),
        hintStyle: TextStyle(color: t.textTert),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: t.card,
        selectedItemColor: t.brand,
        unselectedItemColor: t.textTert,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData get light => _build(AppTokens.light, Brightness.light);
  static ThemeData get dark => _build(AppTokens.dark, Brightness.dark);
}
