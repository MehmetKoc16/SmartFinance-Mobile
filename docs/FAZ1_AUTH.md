# 🔐 Faz 1: Authentication (Kimlik Doğrulama)

**Durum:** ✅ Tamamlandı — 25 Nisan 2026
**Commit:** `185b818`

---

## 🎯 Amacı

Kullanıcının uygulamaya güvenli bir şekilde giriş yapabilmesi, yeni hesap oluşturabilmesi ve oturum bilgisinin cihazda saklanması. Uygulama açıldığında token kontrolü yaparak kullanıcıyı doğru sayfaya yönlendirmek.

---

## 📂 Yazılan Dosyalar

### 1. `lib/services/api_service.dart` ✍️ (Mehmet yazdı)

**Ne yapar:** Backend API ile tüm iletişimi yöneten servis sınıfı.

| Metot | İşlevi |
|-------|--------|
| `baseUrl` | API adresi sabiti (`10.0.2.2:5059` — emülatörden localhost'a erişim) |
| `saveToken(token)` | JWT token'ı SharedPreferences ile telefon hafızasına kaydeder |
| `getToken()` | Kayıtlı token'ı okur (giriş yapılmış mı kontrol için) |
| `removeToken()` | Token'ı siler (çıkış yap fonksiyonu) |
| `isLoggedIn()` | Token var mı? `bool` döner |
| `register({fullName, email, password})` | POST /api/auth/register → başarılıysa token kaydeder |
| `login({email, password})` | POST /api/auth/login → başarılıysa token kaydeder |
| `authenticatedGet(endpoint)` | Token header'ı ile GET isteği (korumalı endpoint'ler için) |
| `authenticatedPost(endpoint, body)` | Token header'ı ile POST isteği (korumalı endpoint'ler için) |

**Kullanılan paketler:**
- `http` — HTTP istekleri yapmak için
- `shared_preferences` — Token'ı telefon hafızasına kaydetmek için
- `dart:convert` — JSON encode/decode

**Önemli kavramlar:**
```dart
// JWT Token: Backend'den gelen kimlik anahtarı
// Her korumalı isteğe header olarak eklenir:
'Authorization': 'Bearer <token>'

// SharedPreferences: Telefonun yerel hafızası (key-value)
// Uygulama kapatılsa bile veri kalır
await prefs.setString('auth_token', token);
```

---

### 2. `lib/main.dart`

**Ne yapar:** Uygulamanın giriş noktası. SplashScreen ile token kontrolü yapar.

**Akış:**
```
Uygulama açılır → SplashScreen (2 sn logo gösterir)
    → ApiService.isLoggedIn() çağrılır
    → Token varsa → MainScreen
    → Token yoksa → LoginScreen
```

**Önemli:** `WidgetsFlutterBinding.ensureInitialized()` — async işlemler main()'de çalışmadan önce Flutter engine'i hazırlar.

---

### 3. `lib/screens/login_screen.dart`

**Ne yapar:** Giriş ekranı UI + API bağlantısı.

**Bileşenler:**
- Gradient SmartFinance logosu (`ShaderMask`)
- Email + Şifre input alanları
- Şifre göster/gizle toggle
- "Giriş Yap" gradient butonu
- Loading spinner (API çağrısı sırasında)
- Hata mesajı (SnackBar — kırmızı bildirim)
- "Kayıt Ol" linki → RegisterScreen'e yönlendirir

**Önemli kavramlar:**
```dart
// TextEditingController: Input alanındaki metni okur
final _emailController = TextEditingController();

// dispose(): Widget silindiğinde hafızayı temizler (memory leak önler)
@override
void dispose() {
  _emailController.dispose();
  super.dispose();
}

// mounted: Widget hala ekranda mı? (async işlem sonrası kontrol)
if (mounted) { Navigator.pushReplacement(...); }

// pushReplacement: Geri tuşuyla önceki sayfaya dönmeyi engeller
Navigator.pushReplacement(context, MaterialPageRoute(...));
```

---

### 4. `lib/screens/register_screen.dart`

**Ne yapar:** Kayıt ekranı UI + validation + API bağlantısı.

**Validation kuralları:**
- Tüm alanlar zorunlu
- Şifre minimum 6 karakter
- Şifre tekrar eşleşmeli

**Login ile farkı:** 4 alan (Ad Soyad, Email, Şifre, Şifre Tekrar) ve `ApiService.register()` çağrısı.

---

### 5. `lib/screens/main_screen.dart`

**Ne yapar:** Giriş başarılı olunca açılan ana ekran. 5 sekmeli alt navigasyon barı.

**Sekmeler:**
```
🏠 Ana Sayfa | 📊 Yatırımlar | ➕ Ekle | 📋 İşlemler | 👤 Profil
```

- ➕ butonu: `showModalBottomSheet` ile "Elle Ekle / PDF ile Ekle / Fotoğraf Çek" menüsü açar
- Profil sekmesinde çıkış butonu: `ApiService.removeToken()` → LoginScreen'e yönlendir

---

## 🎨 Tasarım Dosyaları (Daha önceden oluşturuldu)

### `lib/core/constants/app_colors.dart`
Renk paleti: Arka plan `#0D1117`, kartlar `#161B22`, accent mor `#7C3AED`, cyan `#06B6D4`

### `lib/core/theme/app_theme.dart`
Dark tema: Input dekorasyon stilleri, kart stilleri, BottomNavigationBar teması
