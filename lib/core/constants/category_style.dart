import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class CategoryStyle {
  final IconData icon;
  final Color color;
  const CategoryStyle(this.icon, this.color);
}

/// Backend Category modeli henüz kategori başına ikon/renk saklamıyor
/// (sadece Id+Name). Gerçek kullanıcıların hesabına kayıt sırasında açılan
/// varsayılan kategoriler (bkz. AuthService.cs) + tasarım spesifikasyonundaki
/// isimler için sabit bir eşleme kullanılır; kullanıcının kendi oluşturduğu
/// özel kategoriler isim bazlı deterministik bir renge düşer.
class CategoryStyles {
  static const Map<String, CategoryStyle> _known = {
    // Gerçek varsayılan kategoriler (AuthService.defaultCategories)
    'maas': CategoryStyle(LucideIcons.banknote, Color(0xFF159A5B)),
    'yeme-icme': CategoryStyle(LucideIcons.utensils, Color(0xFFF43F5E)),
    'ulasim': CategoryStyle(LucideIcons.car, Color(0xFF14B8A6)),
    'fatura': CategoryStyle(LucideIcons.receipt, Color(0xFF06B6D4)),
    'atm': CategoryStyle(LucideIcons.landmark, Color(0xFF64748B)),
    'transfer': CategoryStyle(LucideIcons.arrowLeftRight, Color(0xFF3B82F6)),
    'alisveris': CategoryStyle(LucideIcons.shoppingBag, Color(0xFF8B5CF6)),
    'diger': CategoryStyle(LucideIcons.moreHorizontal, Color(0xFF64748B)),
    // Tasarım spesifikasyonundaki ek isimler (ileride kullanıcı bunları da oluşturabilir)
    'market': CategoryStyle(LucideIcons.shoppingCart, Color(0xFF8B5CF6)),
    'kira': CategoryStyle(LucideIcons.home, Color(0xFFF97316)),
    'faturalar': CategoryStyle(LucideIcons.receipt, Color(0xFF06B6D4)),
    'eglence': CategoryStyle(LucideIcons.film, Color(0xFFEC4899)),
    'saglik': CategoryStyle(LucideIcons.heartPulse, Color(0xFF84CC16)),
    'yatirim geliri': CategoryStyle(LucideIcons.trendingUp, Color(0xFF159A5B)),
  };

  static const List<Color> _fallbackPalette = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
    Color(0xFFEAB308),
  ];

  static String _normalize(String s) {
    var r = s.trim().replaceAll('İ', 'i').replaceAll('I', 'i').toLowerCase();
    r = r
        .replaceAll('ı', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    return r;
  }

  static CategoryStyle of(String name) {
    final known = _known[_normalize(name)];
    if (known != null) return known;
    final color = _fallbackPalette[name.hashCode.abs() % _fallbackPalette.length];
    return CategoryStyle(LucideIcons.tag, color);
  }

  // "Yeni Kategori" ikon seçici + backend'in Icon alanı bu kebab-case
  // Lucide adlarını kullanıyor.
  static const Map<String, IconData> iconByName = {
    'shopping-cart': LucideIcons.shoppingCart,
    'shopping-bag': LucideIcons.shoppingBag,
    'home': LucideIcons.home,
    'receipt': LucideIcons.receipt,
    'car': LucideIcons.car,
    'utensils': LucideIcons.utensils,
    'film': LucideIcons.film,
    'heart-pulse': LucideIcons.heartPulse,
    'banknote': LucideIcons.banknote,
    'trending-up': LucideIcons.trendingUp,
    'landmark': LucideIcons.landmark,
    'arrow-left-right': LucideIcons.arrowLeftRight,
    'more-horizontal': LucideIcons.moreHorizontal,
    'gift': LucideIcons.gift,
    'briefcase': LucideIcons.briefcase,
    'graduation-cap': LucideIcons.graduationCap,
    'dumbbell': LucideIcons.dumbbell,
    'plane': LucideIcons.plane,
    'gamepad-2': LucideIcons.gamepad2,
  };

  static const List<Color> colorPicker = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
    Color(0xFFF97316),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
    Color(0xFFEAB308),
    Color(0xFFF43F5E),
    Color(0xFF64748B),
  ];

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceFirst('#', '');
    final value = int.tryParse(clean, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
  }

  /// Backend'den gelen açık Icon/Color varsa onu kullanır (ör. kullanıcının
  /// "Yeni Kategori" ile seçtiği), yoksa isim bazlı sabit eşlemeye düşer.
  static CategoryStyle resolve(String name, {String? icon, String? color}) {
    final resolvedIcon = iconByName[icon];
    final resolvedColor = _parseHex(color);
    if (resolvedIcon != null && resolvedColor != null) {
      return CategoryStyle(resolvedIcon, resolvedColor);
    }
    final fallback = of(name);
    return CategoryStyle(resolvedIcon ?? fallback.icon, resolvedColor ?? fallback.color);
  }
}
