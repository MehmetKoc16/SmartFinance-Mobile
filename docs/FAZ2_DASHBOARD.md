# 📊 Faz 2: Dashboard + İşlemler

**Durum:** ✅ Tamamlandı — 29 Nisan 2026
**Commit:** `ae7147c`

---

## 🎯 Amacı

Ana sayfada kullanıcının aylık gelir/gider durumunu donut chart ile görselleştirmek, yeni işlem (gelir/gider) ekleyebilmesini sağlamak ve tüm işlemleri filtrelenebilir bir listede göstermek.

---

## 📂 Yazılan Dosyalar

### 1. `lib/widgets/transaction_card.dart`

**Ne yapar:** Tekrar kullanılabilir (reusable) işlem kartı bileşeni. Hem Dashboard'da hem İşlemler sayfasında kullanılır.

**Aldığı parametreler:**
| Parametre | Tip | Açıklama |
|-----------|-----|----------|
| `description` | String | İşlem açıklaması ("Market alışverişi") |
| `amount` | double | Tutar (250.50) |
| `type` | int | 1=Gelir, 2=Gider |
| `categoryName` | String | Kategori adı ("Yemek") |
| `date` | String | Tarih ("29 Nis") |

**Görsel davranış:**
- Gelir → yeşil renk + aşağı ok ikonu + `+₺250.50`
- Gider → kırmızı renk + yukarı ok ikonu + `-₺250.50`

**Neden widget olarak ayrıldı?** → DRY prensibi (Don't Repeat Yourself). Aynı kartı birden fazla ekranda tekrar yazmak yerine tek bir widget oluşturup her yerde kullanıyoruz.

---

### 2. `lib/widgets/donut_chart.dart`

**Ne yapar:** fl_chart kütüphanesi ile donut (halka) grafik çizer. Dashboard'da kullanılır.

**Aldığı parametreler:**
- `totalIncome` — Toplam gelir
- `totalExpense` — Toplam gider
- `balance` — Bakiye (gelir - gider)

**Görsel:**
```
     ╭─────╮
    │ Bakiye │  ← Ortadaki yazı (Stack + Column)
    │ ₺12450 │
     ╰─────╯
   🟢 Gelir dilimi
   🔴 Gider dilimi
```

**Kullanılan paket:** `fl_chart` (Flutter chart kütüphanesi)
```dart
PieChart(
  PieChartData(
    sectionsSpace: 3,         // Dilimler arası boşluk
    centerSpaceRadius: 70,    // Ortadaki boşluk (donut efekti)
    sections: [...]           // Dilim verileri
  ),
)
```

---

### 3. `lib/screens/dashboard_screen.dart`

**Ne yapar:** Ana sayfa. Kullanıcının aylık finansal durumunu gösterir.

**Bölümler:**
1. **Üst karşılama:** "Merhaba 👋" + bildirim zili ikonu
2. **Donut chart:** Gelir/gider dağılımı + ortada bakiye
3. **Gelir/Gider kartları:** İki kart yan yana — yeşil gelir, kırmızı gider
4. **Son İşlemler:** Son 5 işlemin listesi (TransactionCard ile)

**API çağrıları:**
```dart
// Aylık özet → donut chart + kartlar
GET /api/transaction/summary/2026/5

// Son işlemler → liste
GET /api/transaction/filter?page=1&pageSize=5
```

**Önemli özellikler:**
- `RefreshIndicator` — Aşağı çekince veriyi yeniler (pull-to-refresh)
- `initState()` içinde `_loadDashboardData()` — Sayfa açılınca otomatik veri çeker
- Tarih formatı: Bugünkü işlemler "Bugün", diğerleri "29 Nis" şeklinde

---

### 4. `lib/screens/add_transaction_screen.dart`

**Ne yapar:** Yeni gelir veya gider ekleme formu.

**Form alanları:**
1. **Gelir/Gider toggle:** İki butonlu seçici (varsayılan: Gider)
2. **Tutar:** ₺ simgeli büyük font input
3. **Açıklama:** Serbest metin
4. **Tarih:** Date picker (takvim açılır)
5. **Kategori:** Dropdown menü (API'den çekilir)

**API çağrıları:**
```dart
// Kategorileri çek (dropdown için)
GET /api/category

// Yeni işlem ekle
POST /api/transaction
{
  "amount": 250.50,
  "description": "Market",
  "transactionDate": "2026-05-01T00:00:00",
  "type": 2,
  "categoryId": 8
}
```

**Önemli kavramlar:**
```dart
// showDatePicker: Flutter'ın yerleşik takvim widget'ı
final picked = await showDatePicker(context: context, ...);

// Navigator.pop(context, true): Önceki sayfaya dön + veri gönder
// true = "yeni işlem eklendi" sinyali → Dashboard yenilensin
Navigator.pop(context, true);

// DropdownButton: Açılır menü — kategorileri listeler
DropdownButton<int>(
  items: _categories.map((cat) => DropdownMenuItem(...)).toList(),
)
```

---

### 5. `lib/screens/transactions_screen.dart`

**Ne yapar:** Tüm işlemlerin filtrelenebilir, sayfalanabilir listesi.

**Özellikler:**
1. **Filtre chip'leri:** Tümü / Gelir / Gider (gradient aktif chip)
2. **İşlem listesi:** TransactionCard bileşenleri ile
3. **Sayfalama:** « Sayfa 1/5 » navigasyonu
4. **Boş durum:** İşlem yoksa bilgilendirme mesajı
5. **Pull-to-refresh:** Aşağı çekince yenile

**API çağrısı:**
```dart
// Filtreli + sayfalı istek
GET /api/transaction/filter?page=1&pageSize=10&type=2
//                          ↑sayfa  ↑adet      ↑gider filtresi
```

**Önemli kavramlar:**
```dart
// Filtre değişince sayfa 1'e dön ve tekrar yükle
void _onFilterChanged(int filter) {
  setState(() {
    _selectedFilter = filter;
    _currentPage = 1;
  });
  _loadTransactions();
}
```

---

### 6. `lib/screens/main_screen.dart` (güncellendi)

**Değişiklik:** Placeholder sayfalar gerçek ekranlarla değiştirildi.

| Sekme | Önceki (Faz 1) | Şimdi (Faz 2) |
|-------|----------------|----------------|
| Ana Sayfa | Placeholder | `DashboardScreen` ✅ |
| İşlemler | Placeholder | `TransactionsScreen` ✅ |
| Yatırımlar | Placeholder | Placeholder (Faz 4) |
| Profil | Placeholder | Placeholder (Faz 3) |

**Yeni akış:** + → Elle Ekle → `AddTransactionScreen` açılır → işlem eklenir → Dashboard + Transactions otomatik yenilenir.

---

## 📦 Eklenen Paketler

| Paket | Versiyon | Amacı |
|-------|----------|-------|
| `intl` | 0.20.2 | Tarih formatlama (DateFormat, Türkçe locale) |
| `flutter_localizations` | SDK | Türkçe dil desteği |
| `fl_chart` | 0.68.0 | Donut chart (pie chart) |

---

## ⚠️ Çözülen Hatalar

1. **fl_chart versiyon uyumsuzluğu:** 1.1.0 → 0.68.0'a düşürüldü (Flutter 3.32 uyumu)
2. **LocaleDataException:** `initializeDateFormatting('tr_TR')` main.dart'a eklendi
3. **authenticatedGet return tipi:** `Map<String,dynamic>` → `dynamic` (backend bazen List döner)
