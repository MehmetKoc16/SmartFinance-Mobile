import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Yatırım tipi ve kategori vurgu renkleri — temadan bağımsız, sabit.
/// (design_handoff_smartfinance/README.md → Asset-type / Category accent colors)
class AppTypeColors {
  static const Map<String, Color> investmentType = {
    'stock': Color(0xFF3B82F6),    // Hisse
    'fund': Color(0xFF14B8A6),     // TEFAS Fon
    'crypto': Color(0xFFF97316),   // Kripto
    'currency': Color(0xFF8B5CF6), // Döviz
    'gold': Color(0xFFEAB308),     // Altın
    'silver': Color(0xFF94A3B8),   // Gümüş
  };

  static const Map<String, String> investmentLabel = {
    'stock': 'Hisse',
    'fund': 'TEFAS Fon',
    'crypto': 'Kripto',
    'currency': 'Döviz',
    'gold': 'Altın',
    'silver': 'Gümüş',
  };

  // Tasarım spec'i sembole özel ikon kullanıyor (THYAO->plane vb.); bizim
  // uygulamada sembol kullanıcı tarafından serbest girildiği için tip
  // bazlı genel bir ikon kullanılıyor.
  static const Map<String, IconData> investmentIcon = {
    'stock': LucideIcons.trendingUp,
    'fund': LucideIcons.pieChart,
    'crypto': LucideIcons.bitcoin,
    'currency': LucideIcons.dollarSign,
    'gold': LucideIcons.circleDollarSign,
    'silver': LucideIcons.coins,
  };

  static const List<Map<String, dynamic>> categoryPresets = [
    {'icon': Icons.restaurant_rounded, 'color': Color(0xFFF43F5E)},   // Yeme-İçme
    {'icon': Icons.shopping_cart_rounded, 'color': Color(0xFF8B5CF6)}, // Market
    {'icon': Icons.directions_bus_rounded, 'color': Color(0xFF14B8A6)}, // Ulaşım
    {'icon': Icons.receipt_rounded, 'color': Color(0xFF06B6D4)},      // Faturalar
    {'icon': Icons.card_giftcard_rounded, 'color': Color(0xFFEC4899)}, // Eğlence
    {'icon': Icons.home_rounded, 'color': Color(0xFFF97316)},         // Kira
    {'icon': Icons.health_and_safety_rounded, 'color': Color(0xFF84CC16)}, // Sağlık
    {'icon': Icons.attach_money_rounded, 'color': Color(0xFF159A5B)}, // Maaş
    {'icon': Icons.school_rounded, 'color': Color(0xFF3B82F6)},
    {'icon': Icons.sports_esports_rounded, 'color': Color(0xFF64748B)}, // Diğer
  ];
}
