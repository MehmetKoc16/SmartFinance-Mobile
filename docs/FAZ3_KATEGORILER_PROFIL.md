# 🗂️ Faz 3: Kategoriler + Profil

**Durum:** ✅ Tamamlandı — 1 Mayıs 2026

---

## 🎯 Amacı

Kullanıcının gelir/gider kategorilerini yönetebilmesi ve kendi profil bilgilerini / istatistiklerini görebilmesi. Ayrıca Dashboard'a ay seçici eklenerek aylara göre veri görüntüleme imkanı sağlandı.

---

## 📂 Yazılan Dosyalar

### 1. `lib/screens/categories_screen.dart` 🆕

**Ne yapar:** Kullanıcının kategorilerini 2 sütunlu grid olarak gösterir ve yeni kategori ekleme imkanı sunar.

**Özellikler:**
| Özellik | Açıklama |
|---------|----------|
| Grid görünüm | 2 sütunlu, renkli ikonlu kart grid'i |
| Gelir/Gider etiketi | Her kartta yeşil "Gelir" veya kırmızı "Gider" etiketi |
| Yeni kategori ekleme | AppBar'daki + ile dialog açılır, isim + tip seçilir |
| Silme (uzun basma) | Kategoriye uzun basınca onay dialog'u |
| Dinamik ikonlar | Her kategori farklı ikon + renk alır (döngüsel) |
| Pull-to-refresh | Aşağı çekince listeyi yeniler |
| Boş durum | Kategori yoksa bilgilendirme mesajı |

**API çağrıları:**
```dart
// Kategorileri listele
GET /api/category

// Yeni kategori oluştur
POST /api/category
{ "name": "Yemek", "type": 2 }
```

**Önemli kavramlar:**
```dart
// StatefulBuilder: Dialog içinde setState kullanabilmek için
showDialog(
  builder: (context) => StatefulBuilder(
    builder: (context, setDialogState) => AlertDialog(...)
  ),
);

// GridView.builder: Performanslı grid listesi
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,       // 2 sütun
    childAspectRatio: 1.3,   // Genişlik/yükseklik oranı
  ),
);

// GestureDetector.onLongPress: Uzun basma aksiyonu
GestureDetector(
  onLongPress: () => _showDeleteConfirmation(cat),
  child: ...
);
```

---

### 2. `lib/screens/profile_screen.dart` 🆕

**Ne yapar:** Kullanıcının profil bilgilerini ve aylık istatistiklerini gösterir.

**Bölümler:**
1. **Avatar:** Gradient daire içinde "SF" baş harfleri
2. **İstatistik kartları:** (2x2 grid)
   - İşlem sayısı
   - Kategori sayısı
   - Toplam gelir (yeşil)
   - Toplam gider (kırmızı)
3. **Ayarlar listesi:**
   - Profil Düzenle
   - Bildirimler
   - Tema
   - Şifre Değiştir
   - Yardım
4. **Çıkış yap:** Onay dialog'u ile güvenli çıkış
5. **Versiyon:** `SmartFinance v1.0.0`

**API çağrıları:**
```dart
// İstatistikler için aylık özet
GET /api/transaction/summary/{year}/{month}

// Kategori sayısı için
GET /api/category
```

**Önemli kavramlar:**
```dart
// Çıkış onayı: Kullanıcının yanlışlıkla çıkmasını engeller
void _showLogoutConfirmation() {
  showDialog(
    builder: (context) => AlertDialog(
      title: Text('Çıkış Yap'),
      content: Text('Emin misiniz?'),
      actions: [
        TextButton(child: Text('İptal')),
        ElevatedButton(
          onPressed: _logout,   // Token sil + Login'e yönlendir
          child: Text('Çıkış Yap'),
        ),
      ],
    ),
  );
}
```

---

### 3. `lib/screens/dashboard_screen.dart` (güncellendi)

**Eklenen özellikler:**

#### Ay Seçici
```
◀  Nisan 2026  ▶
```
- Sol ok: Önceki aya git
- Sağ ok: Sonraki aya git (bu aydan ileriye gidemez)
- Türkçe ay adı: `DateFormat('MMMM yyyy', 'tr_TR')`
- Ay değişince donut chart + gelir/gider kartları otomatik güncellenir

#### Kategori Adı Çözümleme
Backend response'da `categoryName` alanı olmadığı için:
1. Tüm kategoriler çekilir → `Map<int, String>` oluşturulur
2. Her transaction'ın `categoryId`'si bu map'ten çözümlenir
3. "Kategori" yerine gerçek isim gösterilir (örn: "Maas", "Market")

```dart
// Kategori map oluşturma
_categoryMap = {for (var c in categories) c['id'] as int: c['name'] as String};
// Örnek: {8: "Yemek", 9: "Market", 10: "Ulasim", 11: "Maas"}

// Kullanım
String _getCategoryName(dynamic transaction) {
  final catId = transaction['categoryId'];
  if (_categoryMap.containsKey(catId)) return _categoryMap[catId]!;
  return 'Kategori';
}
```

---

### 4. `lib/screens/transactions_screen.dart` (güncellendi)

**Değişiklikler:**
- Kategori adı çözümleme eklendi (aynı mantık)
- `response.containsKey` → `response is Map && response.containsKey` güvenli kontrol

---

### 5. `lib/screens/main_screen.dart` (güncellendi)

**Değişiklikler:**
- Profil sekmesi: Placeholder → `ProfileScreen` ✅
- + menüsüne "Kategoriler" seçeneği eklendi (CategoriesScreen'e yönlendirir)
- Eski `_ProfilePage` placeholder widget'ı kaldırıldı
- `_refreshPages()` metodu ile Dashboard + Transactions aynı anda yenilenebiliyor

---

### 6. `docs/FAZ1_AUTH.md` 🆕

Faz 1'de yazılan tüm dosyaların detaylı açıklaması ve kavramlar.

### 7. `docs/FAZ2_DASHBOARD.md` 🆕

Faz 2'de yazılan dosyalar, API çağrıları ve çözülen hataların dökümantasyonu.

---

## ⚠️ Çözülen Hatalar

1. **Donut chart ₺0 gösteriyordu:** Ay seçici eklenerek kullanıcı doğru aya gidebiliyor
2. **Kategori adı "Kategori" yazıyordu:** `categoryId` → `categoryName` map çözümlemesi eklendi
3. **authenticatedGet return tipi:** `Map` → `dynamic` (backend List de dönebilir)
4. **response.containsKey hatası:** `response is Map` kontrolü eklendi

---

## 📋 Bilinen Eksikler (İleride)

- [ ] Kategori düzenleme (şu an sadece ekleme var)
- [ ] Kategori silme (backend'de DELETE endpoint var ama `authenticatedDelete` metodu yok)
- [ ] Profil düzenleme / şifre değiştirme (butonlar pasif)
- [ ] Maaş günü ayarı (ileride profil ayarlarına eklenecek)
