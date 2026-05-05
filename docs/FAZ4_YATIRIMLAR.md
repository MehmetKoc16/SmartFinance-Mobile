# 📈 Faz 4: Yatırımlar

**Durum:** ✅ Tamamlandı — 5 Mayıs 2026

---

## 🎯 Amacı

Kullanıcının yatırım portföyünü (hisse, altın, döviz, kripto) görsel olarak takip edebilmesini sağlamak. Backend'de henüz yatırım endpoint'i olmadığı için **mock (örnek) veri** ile çalışılmaktadır. İleride gerçek piyasa API'si entegre edilecektir.

---

## 📂 Yazılan Dosyalar

### 1. `lib/screens/investments_screen.dart` 🆕

**Ne yapar:** Yatırım portföyünü görselleştirir.

**Bölümler:**

| # | Bölüm | Açıklama |
|---|-------|----------|
| 1 | **Portföy kartı** | Gradient kart: toplam değer + günlük değişim (₺ ve %) |
| 2 | **Periyod seçici** | 1H / 1A / 3A / 1Y chip'leri |
| 3 | **Çizgi grafik** | fl_chart LineChart — 7 günlük performans, dokunulunca değer gösterir |
| 4 | **Yatırım listesi** | Her yatırım için: ikon + isim + mini sparkline + fiyat + değişim % |
| 5 | **Uyarı notu** | "Veriler örnek amaçlıdır" bilgilendirmesi |

**Mock veriler:**
```dart
// 6 adet yatırım
'THYAO'    → Türk Hava Yolları  → ₺312.40  (+2.15%)
'Altın'    → Gram Altın         → ₺3285.00 (-0.42%)
'SASA'     → SASA Polyester     → ₺58.70   (+4.32%)
'USD/TRY'  → Amerikan Doları    → ₺38.42   (+0.18%)
'EUR/TRY'  → Euro               → ₺41.85   (-0.25%)
'BTC'      → Bitcoin            → ₺96520   (+1.87%)
```

**Kullanılan fl_chart bileşenleri:**

```dart
// Ana çizgi grafik (LineChart)
LineChart(
  LineChartData(
    lineBarsData: [
      LineChartBarData(
        spots: data.map((e) => FlSpot(...)).toList(),
        isCurved: true,           // Yumuşak eğri
        belowBarData: BarAreaData( // Alt gölgeleme
          show: true,
          color: purple.withOpacity(0.1),
        ),
      ),
    ],
  ),
);

// Mini sparkline (her yatırım kartında)
// Aynı LineChart ama küçük, dokunma devre dışı
SizedBox(
  width: 60, height: 30,
  child: LineChart(
    LineChartData(
      lineTouchData: LineTouchData(enabled: false),
      ...
    ),
  ),
);
```

**Önemli kavramlar:**
```dart
// FlSpot: Grafik üzerindeki nokta (x, y)
FlSpot(0, 124200)  // İlk gün, ₺124,200

// asMap().entries: List'i index ile birlikte döndürür
sparkline.asMap().entries.map((e) =>
  FlSpot(e.key.toDouble(), e.value),
).toList();
// Sonuç: [FlSpot(0, 295), FlSpot(1, 300), FlSpot(2, 305), ...]

// Gradient kart: Container'a gradient uygulama
Container(
  decoration: BoxDecoration(
    gradient: AppColors.gradientPurpleCyan,
    borderRadius: BorderRadius.circular(18),
  ),
);
```

---

### 2. `lib/screens/main_screen.dart` (güncellendi)

**Değişiklikler:**
- `_PlaceholderPage` widget'ı tamamen kaldırıldı (artık placeholder yok!)
- Yatırımlar sekmesi: Placeholder → `InvestmentsScreen` ✅
- `investments_screen.dart` import'u eklendi

---

## 📦 Commit Geçmişi

Bu fazda **parça parça commit** yaklaşımına geçildi:

| # | Commit | Mesaj |
|---|--------|-------|
| 1 | `2c3ab48` | `feat: yatirimlar ekrani - portfolio, cizgi grafik, sparkline listesi` |
| 2 | `d71b034` | `refactor: main_screen placeholder kaldirildi, InvestmentsScreen entegre edildi` |
| 3 | — | `docs: faz 4 dokumantasyonu ve PROJE_REHBERI guncellendi` |

---

## 🔮 İleride Yapılacaklar

- [ ] Backend'e yatırım endpoint'leri ekle (CRUD)
- [ ] Gerçek piyasa API'si entegrasyonu (Borsa İstanbul, altın, döviz)
- [ ] Portföy hesaplaması (alış fiyatı vs güncel fiyat)
- [ ] Yatırım ekleme/çıkarma formu
- [ ] Periyod seçiciye göre farklı veri gösterimi (1 hafta / 1 ay / 3 ay / 1 yıl)
