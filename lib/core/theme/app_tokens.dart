import 'package:flutter/material.dart';

/// Tasarım teslim paketindeki (design_handoff_smartfinance) token sistemi —
/// açık/koyu tema arasında geçiş yapılabilsin diye tüm renkler burada,
/// ekranlar asla ham renk değeri yazmaz, hep AppTokens.of(context) üzerinden okur.
class AppTokens extends ThemeExtension<AppTokens> {
  final Color bg;
  final Color card;
  final Color elevated;
  final Color border;
  final Color divider;
  final Color text;
  final Color textSec;
  final Color textTert;
  final Color brand;
  final Color brandDeep;
  final Color brandSoft;
  final Color green;
  final Color greenSoft;
  final Color red;
  final Color redSoft;
  final Color amber;
  final Color amberSoft;
  final Color navBg;
  final Color inputBg;

  const AppTokens({
    required this.bg,
    required this.card,
    required this.elevated,
    required this.border,
    required this.divider,
    required this.text,
    required this.textSec,
    required this.textTert,
    required this.brand,
    required this.brandDeep,
    required this.brandSoft,
    required this.green,
    required this.greenSoft,
    required this.red,
    required this.redSoft,
    required this.amber,
    required this.amberSoft,
    required this.navBg,
    required this.inputBg,
  });

  static const light = AppTokens(
    bg: Color(0xFFF7F8FA),
    card: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    border: Color(0x170B0E14),
    divider: Color(0x0F0B0E14),
    text: Color(0xFF0B0E14),
    textSec: Color(0x990B0E14),
    textTert: Color(0x660B0E14),
    brand: Color(0xFF3B82F6),
    brandDeep: Color(0xFF2563EB),
    brandSoft: Color(0x1A3B82F6),
    green: Color(0xFF159A5B),
    greenSoft: Color(0x1A159A5B),
    red: Color(0xFFDC2647),
    redSoft: Color(0x1ADC2647),
    amber: Color(0xFFB45309),
    amberSoft: Color(0x1AB45309),
    navBg: Color(0xDBFFFFFF),
    inputBg: Color(0xFFF0F2F5),
  );

  static const dark = AppTokens(
    bg: Color(0xFF0B0E14),
    card: Color(0xFF151A23),
    elevated: Color(0xFF1C2230),
    border: Color(0x17FFFFFF),
    divider: Color(0x0FFFFFFF),
    text: Color(0xFFF5F7FA),
    textSec: Color(0x9EF5F7FA),
    textTert: Color(0x66F5F7FA),
    brand: Color(0xFF5B9BFF),
    brandDeep: Color(0xFF2E5FCC),
    brandSoft: Color(0x2E5B9BFF),
    green: Color(0xFF34D399),
    greenSoft: Color(0x2934D399),
    red: Color(0xFFFB7185),
    redSoft: Color(0x29FB7185),
    amber: Color(0xFFFBBF24),
    amberSoft: Color(0x29FBBF24),
    navBg: Color(0xDB151A23),
    inputBg: Color(0xFF11151D),
  );

  static AppTokens of(BuildContext context) =>
      Theme.of(context).extension<AppTokens>() ?? dark;

  @override
  AppTokens copyWith({
    Color? bg, Color? card, Color? elevated, Color? border, Color? divider,
    Color? text, Color? textSec, Color? textTert,
    Color? brand, Color? brandDeep, Color? brandSoft,
    Color? green, Color? greenSoft, Color? red, Color? redSoft,
    Color? amber, Color? amberSoft, Color? navBg, Color? inputBg,
  }) {
    return AppTokens(
      bg: bg ?? this.bg,
      card: card ?? this.card,
      elevated: elevated ?? this.elevated,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      text: text ?? this.text,
      textSec: textSec ?? this.textSec,
      textTert: textTert ?? this.textTert,
      brand: brand ?? this.brand,
      brandDeep: brandDeep ?? this.brandDeep,
      brandSoft: brandSoft ?? this.brandSoft,
      green: green ?? this.green,
      greenSoft: greenSoft ?? this.greenSoft,
      red: red ?? this.red,
      redSoft: redSoft ?? this.redSoft,
      amber: amber ?? this.amber,
      amberSoft: amberSoft ?? this.amberSoft,
      navBg: navBg ?? this.navBg,
      inputBg: inputBg ?? this.inputBg,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      card: Color.lerp(card, other.card, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSec: Color.lerp(textSec, other.textSec, t)!,
      textTert: Color.lerp(textTert, other.textTert, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      brandDeep: Color.lerp(brandDeep, other.brandDeep, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenSoft: Color.lerp(greenSoft, other.greenSoft, t)!,
      red: Color.lerp(red, other.red, t)!,
      redSoft: Color.lerp(redSoft, other.redSoft, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberSoft: Color.lerp(amberSoft, other.amberSoft, t)!,
      navBg: Color.lerp(navBg, other.navBg, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
    );
  }
}
