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
}
