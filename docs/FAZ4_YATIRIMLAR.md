# 📈 Faz 4: Yatırım Yönetim Modülü

> **Tamamlanma Tarihi:** 5 Mayıs 2026
> **Kapsam:** Backend + Frontend + API Entegrasyonu

---

## 🎯 Amacı

Kullanıcıların hisse senedi, altın, döviz ve kripto yatırımlarını takip edebilmesi için uçtan uca (backend → database → API → Flutter UI) bir yatırım yönetim modülü oluşturmak.

---

## 🏗️ Backend Mimarisi (C# .NET 9)

### Katmanlı Yapı

```
SmartFinance.Domain/Entities/Investment.cs           → Entity
SmartFinance.Application/DTOs/Investment/             → DTO'lar (3 dosya)
SmartFinance.Application/Interfaces/IInvestmentService.cs → Servis kontratı
SmartFinance.Infrastructure/Configurations/           → EF Core config
SmartFinance.Infrastructure/Services/InvestmentService.cs → İş mantığı
SmartFinance.API/Controllers/InvestmentController.cs  → API endpoint'leri
```

### Investment Entity Property'leri

| Property | Tip | Açıklama |
|----------|-----|----------|
| Id | int | PK (BaseEntity'den) |
| Name | string(50) | Sembol: THYAO, BTC |
| FullName | string(200) | Tam ad: Türk Hava Yolları |
| PurchasePrice | decimal(18,4) | Alış fiyatı |
| CurrentPrice | decimal(18,4) | Güncel fiyat |
| Quantity | double | Adet veya gram |
| InvestmentType | string(50) | stock, gold, currency, crypto |
| UserId | int | FK → User |
| CreatedDate | DateTime | BaseEntity'den |
| UpdatedDate | DateTime? | BaseEntity'den |
| IsDeleted | bool | Soft delete (BaseEntity'den) |

### API Endpoint'leri

| HTTP | URL | Açıklama |
|------|-----|----------|
| GET | /api/investment | Kullanıcının tüm yatırımları |
| GET | /api/investment/{id} | Tek yatırım detayı |
| GET | /api/investment/summary | Portföy özeti |
| POST | /api/investment | Yatırım ekle |
| PUT | /api/investment/{id} | Yatırım güncelle |
| DELETE | /api/investment/{id} | Yatırım sil (soft delete) |

### InvestmentDto Hesaplanmış Property'ler

DTO içinde backend tarafında hesaplanan property'ler:
- `TotalPurchaseValue` = PurchasePrice × Quantity
- `TotalCurrentValue` = CurrentPrice × Quantity
- `ProfitLoss` = TotalCurrentValue - TotalPurchaseValue
- `ProfitLossPercentage` = (ProfitLoss / TotalPurchaseValue) × 100

### PortfolioSummaryDto

Kullanıcının tüm portföy özetini döner:
- Toplam alış değeri, toplam güncel değer
- Toplam kar/zarar ve yüzdesel değişim
- `ByType`: Yatırım türlerine göre gruplu dağılım

---

## 📱 Frontend (Flutter)

### investments_screen.dart

| Bileşen | Açıklama |
|---------|----------|
| Portföy Kartı | Gradient kart, toplam değer + kar/zarar + yüzde |
| Tür Dağılımı | stock/gold/currency/crypto bazlı gruplu kartlar |
| Yatırım Listesi | Her yatırımın sembol, isim, adet, fiyat, kar/zarar bilgisi |
| Ekleme Dialog | Sembol, tam ad, alış fiyatı, güncel fiyat, miktar, tür dropdown |
| Silme | Karta uzun basarak silme onayı |
| RefreshIndicator | Aşağı çekerek yenileme |

### api_service.dart Güncellemeleri

Bu fazda eklenen yeni HTTP metotları:
- `authenticatedPut(endpoint, body)` — Yatırım güncelleme
- `authenticatedDelete(endpoint)` — Yatırım silme

Her ikisi de boş body kontrolü yapıyor (204 NoContent desteği).

---

## 🔧 Karşılaşılan Sorunlar ve Çözümler

### 1. GenericRepository Uyumsuzluğu
**Sorun:** Prompt'ta `GetQueryable()` ve `UpdateAsync()` kullanılmıştı ama mevcut `IGenericRepository`'de bu metotlar yoktu.
**Çözüm:** TransactionService pattern'i uygulandı — `GetAllAsync()` + LINQ filtreleme + `_repository.Update()` + `_context.SaveChangesAsync()`.

### 2. Migration FK Çakışması
**Sorun:** EF Core migration'ı otomatik olarak seed user'ı silmeye çalıştı (`DeleteData Users Id=1`), bu da FK constraint ihlali verdi.
**Çözüm:** Migration dosyasından `DeleteData` ve `InsertData` satırları manuel olarak kaldırıldı.

### 3. 401 Unauthorized (Token Süresi)
**Sorun:** Emülatörde yatırım eklenemiyordu.
**Çözüm:** Token süresi dolmuştu, kullanıcı tekrar giriş yaptıktan sonra düzeldi.

---

## ⚠️ Teknik Borç: Güncel Fiyat API

Şu an kullanıcı güncel fiyatı **manuel** giriyor. Gerçek uygulamada dış API'lerden otomatik çekilmeli:

| Tür | API | Ücretsiz? |
|-----|-----|-----------|
| Hisse (BIST) | CollectAPI / TCMB | ✅ |
| Altın | CollectAPI | ✅ |
| Döviz | ExchangeRate API / TCMB | ✅ |
| Kripto | CoinGecko API | ✅ |

Bu entegrasyon ilerideki fazlarda yapılacak.

---

## 📊 Git Commit'leri

| Commit | Mesaj |
|--------|-------|
| `943ad65` | feat: added Investment entity and DTOs |
| `7644c49` | feat: added PortfolioSummaryDto and IInvestmentService |
| `45b2a0f` | feat: InvestmentService, Controller, DbContext, DI, Migration |
| `88eaca1` | feat: InvestmentsScreen API entegrasyonu + authenticatedPut/Delete |
