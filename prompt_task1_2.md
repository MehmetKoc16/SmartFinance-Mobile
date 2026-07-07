# SmartFinance — Görev: İşlem Düzenleme/Silme + Kullanıcı Profili

## Proje Hakkında

SmartFinance bir kişisel finans yönetim uygulamasıdır.
- **Backend**: ASP.NET Core 9, `C:\Users\pc\Desktop\Proje\SmartFinance\`
- **Frontend**: Flutter, `C:\Users\pc\Desktop\Proje\SmartFinance-Mobile\`
- Proje yapısı, pattern'ler ve teknik detaylar için: `C:\Users\pc\Desktop\Proje\SmartFinance\PROJE_DURUMU.md`

---

## Yapılacaklar (2 Görev)

---

### GÖREV 1 — İşlem Düzenleme ve Silme

#### 1A. Backend — `AuthController`'a kullanıcı bilgisi endpoint'i ekle

**Dosya**: `SmartFinance.API/Controllers/AuthController.cs`

Mevcut Auth controller'a yeni bir endpoint ekle:

```csharp
[HttpGet("me")]
[Authorize]
public IActionResult GetMe()
{
    var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
    var email  = User.FindFirst(ClaimTypes.Email)?.Value;
    var name   = User.FindFirst(ClaimTypes.Name)?.Value;
    return Ok(new { id = userId, email, fullName = name });
}
```

`using System.Security.Claims;` ve `using Microsoft.AspNetCore.Authorization;` import'larını ekle.

---

#### 1B. Flutter — Transactions ekranına düzenleme ve silme ekle

**Dosya**: `SmartFinance-Mobile/lib/screens/transactions_screen.dart`

Şu an `TransactionCard` widget'ları sadece görüntüleniyor, tıklanınca hiçbir şey olmuyor. Şunları ekle:

**1. Uzun basma (long press) ile silme:**
`ListView.builder` içindeki `TransactionCard`'ı `GestureDetector` ile sar:

```dart
GestureDetector(
  onLongPress: () => _showDeleteDialog(t['id'], index),
  onTap: () => _showEditDialog(t),
  child: TransactionCard(...)
)
```

**2. Silme dialog'u — `_showDeleteDialog` metodu:**
```dart
Future<void> _showDeleteDialog(int id, int index) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('İşlemi Sil', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('Bu işlemi silmek istediğinize emin misiniz?',
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('İptal', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: const Text('Sil'),
        ),
      ],
    ),
  );
  if (confirm == true) {
    await ApiService.authenticatedDelete('/transaction/$id');
    setState(() {
      _transactions.removeAt(index);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('İşlem silindi.'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      );
    }
  }
}
```

**3. Düzenleme bottom sheet — `_showEditDialog` metodu:**

Aşağı kayarak açılan bir ModalBottomSheet ile düzenleme formu göster. Form alanları:
- Tutar (TextEditingController, sayısal klavye)
- Açıklama (TextEditingController)
- Tarih (DatePicker)
- Kategori (DropdownButton — `_categoryMap`'ten besle)
- Gelir/Gider tipi toggle

"Güncelle" butonuna basınca:
```dart
await ApiService.authenticatedPut('/transaction/${t['id']}', {
  'amount': amount,
  'description': description,
  'transactionDate': date.toIso8601String(),
  'type': type,
  'categoryId': categoryId,
});
```
Başarılıysa `_loadTransactions()` çağır, bottom sheet'i kapat, "İşlem güncellendi" snackbar göster.

---

**4. `ApiService`'e eksik metotlar ekle:**

**Dosya**: `SmartFinance-Mobile/lib/services/api_service.dart`

Mevcut `authenticatedPost` ve `authenticatedGet` metodlarının yanına şunları ekle:

```dart
static Future<dynamic> authenticatedPut(String endpoint, Map<String, dynamic> body) async {
  try {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body);
  } catch (e) {
    return {'error': 'Bağlantı hatası: $e'};
  }
}

static Future<dynamic> authenticatedDelete(String endpoint) async {
  try {
    final token = await getToken();
    final response = await http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return response.statusCode == 204 ? {'success': true} : {'error': 'Silinemedi'};
  } catch (e) {
    return {'error': 'Bağlantı hatası: $e'};
  }
}
```

---

### GÖREV 2 — Kullanıcı Bilgisi ve Profil

#### 2A. Flutter — Profil ekranında gerçek kullanıcı bilgisini göster

**Dosya**: `SmartFinance-Mobile/lib/screens/profile_screen.dart`

**Mevcut sorun**: Avatar'da "SF" hardcoded, isim "SmartFinance" hardcoded yazıyor.

**Yapılacaklar:**

1. Sınıfa `String _userName = ''` ve `String _userEmail = ''` field'larını ekle.

2. `_loadProfileData()` içine şunu ekle:
```dart
final me = await ApiService.authenticatedGet('/auth/me');
if (me is Map) {
  _userName  = me['fullName'] ?? '';
  _userEmail = me['email']   ?? '';
}
```

3. Avatar'daki "SF" metnini kullanıcının baş harfleriyle değiştir:
```dart
// "Mehmet Koç" -> "MK"
String get _initials {
  final parts = _userName.trim().split(' ');
  if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  if (parts.isNotEmpty && parts[0].isNotEmpty) return parts[0][0].toUpperCase();
  return 'SF';
}
```

4. İsim ve e-posta gösterimlerini güncelle:
```dart
Text(_userName.isNotEmpty ? _userName : 'Kullanıcı', ...)
Text(_userEmail.isNotEmpty ? _userEmail : '', ...)
```

---

#### 2B. Flutter — Şifre Değiştirme

**Dosya**: `SmartFinance-Mobile/lib/screens/profile_screen.dart`

**Backend**: Şifre değiştirme endpoint'i henüz yok. Önce backend'e ekle.

**Backend — `AuthController.cs`'e ekle:**
```csharp
[HttpPut("change-password")]
[Authorize]
public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDto dto)
{
    await _authService.ChangePasswordAsync(dto);
    return NoContent();
}
```

**`ChangePasswordDto`** (`Application/DTOs/Auth/ChangePasswordDto.cs`):
```csharp
namespace SmartFinance.Application.DTOs.Auth;
public class ChangePasswordDto
{
    public string CurrentPassword { get; set; } = string.Empty;
    public string NewPassword     { get; set; } = string.Empty;
}
```

**`IAuthService`'e ekle:**
```csharp
Task ChangePasswordAsync(ChangePasswordDto dto);
```

**`AuthService.cs`'e ekle:**
```csharp
public async Task ChangePasswordAsync(ChangePasswordDto dto)
{
    var userId = int.Parse(_httpContextAccessor.HttpContext!.User
        .FindFirst(ClaimTypes.NameIdentifier)!.Value);
    var user = await _context.Users.FindAsync(userId)
        ?? throw new NotFoundException("Kullanıcı bulunamadı!");
    if (!BCrypt.Net.BCrypt.Verify(dto.CurrentPassword, user.PasswordHash))
        throw new BadRequestException("Mevcut şifre hatalı!");
    user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.NewPassword);
    user.UpdatedDate  = DateTime.UtcNow;
    await _context.SaveChangesAsync();
}
```
`AuthService`'e `IHttpContextAccessor` enjekte edilmesi gerekiyor — `Program.cs`'te `builder.Services.AddHttpContextAccessor();` zaten var.

**Flutter — Profil ekranındaki "Şifre Değiştir" butonunu çalıştır:**

`_buildSettingsTile(Icons.lock_rounded, 'Şifre Değiştir', () {})` satırındaki `() {}` yerine şu metodu çağır:

```dart
void _showChangePasswordSheet() {
  final currentCtrl = TextEditingController();
  final newCtrl     = TextEditingController();
  final confirmCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBg,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24,
          MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Şifre Değiştir',
              style: TextStyle(color: AppColors.textPrimary,
                  fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          // Mevcut Şifre alanı
          // Yeni Şifre alanı
          // Yeni Şifre (Tekrar) alanı
          // Kaydet butonu → POST /api/auth/change-password
          // Başarılıysa: "Şifre değiştirildi" snackbar, bottom sheet kapat
          // Hatalıysa: "Mevcut şifre hatalı" snackbar
        ],
      ),
    ),
  );
}
```

---

## Kontrol Listesi

Backend:
- [ ] `GET /api/auth/me` endpoint'i eklendi
- [ ] `PUT /api/auth/change-password` endpoint'i eklendi
- [ ] `ChangePasswordDto` oluşturuldu
- [ ] `IAuthService.ChangePasswordAsync` eklendi
- [ ] `AuthService.ChangePasswordAsync` implemente edildi
- [ ] `build` başarılı

Flutter:
- [ ] `authenticatedPut` metodu `api_service.dart`'a eklendi
- [ ] `authenticatedDelete` metodu `api_service.dart`'a eklendi
- [ ] `transactions_screen.dart`'ta silme dialog'u çalışıyor
- [ ] `transactions_screen.dart`'ta düzenleme bottom sheet çalışıyor
- [ ] `profile_screen.dart`'ta gerçek isim ve e-posta gösteriliyor
- [ ] `profile_screen.dart`'ta avatar baş harfleri gösteriyor
- [ ] `profile_screen.dart`'ta şifre değiştirme çalışıyor
- [ ] `flutter analyze` temiz

## Önemli Notlar
- Backend pattern'leri için `PROJE_DURUMU.md` dosyasını oku
- Soft delete kullan (IsDeleted = true)
- Her serviste UserId izolasyonu yap
- AppColors sınıfından renkleri kullan, hardcoded renk yazma
