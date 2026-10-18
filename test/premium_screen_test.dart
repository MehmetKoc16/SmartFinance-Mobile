import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:smartfinance_mobile/core/theme/app_theme.dart';
import 'package:smartfinance_mobile/screens/premium_screen.dart';
import 'package:smartfinance_mobile/screens/profile_screen.dart';
import 'package:smartfinance_mobile/services/billing_service.dart';
import 'package:smartfinance_mobile/services/links.dart';

import 'helpers/test_app.dart';

class FakeStoreGateway implements StoreGateway {
  final events = StreamController<List<PurchaseDetails>>.broadcast(sync: true);
  bool available = true;
  List<ProductDetails> products = [
    ..._products(BillingService.premiumMonthly, '₺99,00', 99000000),
    ..._products(BillingService.premiumYearly, '₺799,00', 799000000),
  ];
  final bought = <ProductDetails>[];
  final accountTokens = <String?>[];
  final completed = <PurchaseDetails>[];
  Set<String>? queriedIds;
  int restoreCalls = 0;
  List<PurchaseDetails> restored = [];
  bool buyResult = true;

  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<ProductDetailsResponse> queryProducts(Set<String> ids) async {
    queriedIds = ids;
    return ProductDetailsResponse(productDetails: products, notFoundIDs: []);
  }
  @override
  Future<bool> buy(ProductDetails product, {String? accountToken}) async {
    bought.add(product);
    accountTokens.add(accountToken);
    return buyResult;
  }
  @override
  Future<void> restore() async {
    restoreCalls++;
    if (restored.isNotEmpty) events.add(restored);
  }
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => events.stream;
  @override
  Future<void> completePurchase(PurchaseDetails purchase) async => completed.add(purchase);
}

List<GooglePlayProductDetails> _products(String id, String price, int micros, {bool trial = true}) {
  final recurring = PricingPhaseWrapper(
    billingCycleCount: 0,
    billingPeriod: id == BillingService.premiumMonthly ? 'P1M' : 'P1Y',
    formattedPrice: price,
    priceAmountMicros: micros,
    priceCurrencyCode: 'TRY',
    recurrenceMode: RecurrenceMode.infiniteRecurring,
  );
  return GooglePlayProductDetails.fromProductDetails(ProductDetailsWrapper(
    description: 'Premium',
    name: 'Premium',
    productId: id,
    productType: ProductType.subs,
    title: 'Premium',
    subscriptionOfferDetails: [
      SubscriptionOfferDetailsWrapper(
        basePlanId: 'base', offerTags: const [], offerIdToken: '$id-base',
        pricingPhases: [recurring],
      ),
      if (trial)
        SubscriptionOfferDetailsWrapper(
          basePlanId: 'base', offerId: 'trial', offerTags: const [], offerIdToken: '$id-trial',
          pricingPhases: [
            const PricingPhaseWrapper(
              billingCycleCount: 1, billingPeriod: 'P7D', formattedPrice: 'Ücretsiz',
              priceAmountMicros: 0, priceCurrencyCode: 'TRY', recurrenceMode: RecurrenceMode.finiteRecurring,
            ),
            recurring,
          ],
        ),
    ],
  ));
}

Map<String, dynamic> _status({bool premium = false, bool renewing = true, bool pending = false}) => {
  'isPremium': premium,
  'expiresAt': premium ? '2026-11-04T12:00:00Z' : null,
  'autoRenewing': renewing,
  'accountToken': 'hesaba-ozel-sunucu-jetonu',
  'purchasePending': pending,
  'investments': {'used': 1, 'limit': 8},
  'budgets': {'used': 1, 'limit': 4},
  'monthlyImports': {'used': 1, 'limit': 6},
  'indicatorsIncluded': premium,
};

PurchaseDetails _purchase(PurchaseStatus status, {bool complete = true}) => PurchaseDetails(
  purchaseID: 'siparis', productID: BillingService.premiumYearly,
  verificationData: PurchaseVerificationData(
    localVerificationData: 'yerel-veri-kullanilmaz',
    serverVerificationData: 'play-satin-alma-jetonu', source: 'google_play',
  ),
  transactionDate: '1791115200000', status: status,
)..pendingCompletePurchase = complete;

Iterable<Uri> _verifyRequests() => fakeApiRequests.where((u) => u.path.endsWith('/subscription/verify'));

Future<void> _open(WidgetTester tester, {ThemeData? theme}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(testApp(const PremiumScreen(), theme: theme));
  await settle(tester);
}

void main() {
  late FakeStoreGateway store;

  // Servis future'ları ve stream kapanışları testin FakeAsync bölgesinde
  // tamamlanmalı; dışarıdaki tearDown artık bu bölgenin kuyruğunu ilerletemez.
  void premiumTest(String name, WidgetTesterCallback body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(tester);
        await pumpUntilDone(tester, BillingService.resetForTest());
        // Dinleyicisi olmayan StreamController'ın close() Future'ı hiç tamamlanmaz.
        store.events.close().ignore();
      }
    });
  }

  setUp(() async {
    store = FakeStoreGateway();
    BillingService.gateway = store;
    await setUpFakeApi(subscriptionStatus: _status(), subscriptionVerifyResult: _status(premium: true));
  });
  tearDown(tearDownFakeApi);

  premiumTest('EkranKapaliykenGelenSatinAlma_DogrulanirVeTamamlanir', (tester) async {
    await pumpUntilDone(tester, BillingService().startAppWide());
    await _open(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
    store.events.add([_purchase(PurchaseStatus.purchased)]);
    await settle(tester);
    expect(_verifyRequests(), hasLength(1));
    expect(store.completed, hasLength(1));
  });

  premiumTest('AcilistaPremiumDegilse_SessizGeriYuklemeYapilir', (tester) async {
    store.restored = [_purchase(PurchaseStatus.restored)];
    await pumpUntilDone(tester, BillingService().startAppWide());
    await pumpUntilDone(tester, BillingService().startAppWide());
    expect(store.restoreCalls, 1);
    expect(store.completed, hasLength(1));
  });

  premiumTest('AcilistaPremiumsa_GeriYuklemeYapilmaz', (tester) async {
    await setUpFakeApi(subscriptionStatus: _status(premium: true));
    await pumpUntilDone(tester, BillingService().startAppWide());
    expect(store.restoreCalls, 0);
  });

  premiumTest('CikistaDinleyiciDurur_VeBekleyenDogrulamalarSilinir', (tester) async {
    await setUpFakeApi(subscriptionStatus: _status(), subscriptionVerifyStatus: 500);
    store.restored = [_purchase(PurchaseStatus.restored)];
    await pumpUntilDone(tester, BillingService().startAppWide());
    expect(BillingService().canRetryVerification, true);
    await pumpUntilDone(tester, BillingService().stopAppWide());
    expect(store.events.hasListener, false);
    expect(BillingService().canRetryVerification, false);
    expect(BillingService().status, null);
    store.events.add([_purchase(PurchaseStatus.purchased)]);
    await settle(tester);
    expect(_verifyRequests(), hasLength(1));
  });

  premiumTest('CikistaSurmekteOlanDogrulamaYeniOturumuDegistirmez', (tester) async {
    await setUpFakeApi(subscriptionStatus: _status(),
      subscriptionVerifyResult: _status(premium: true),
      subscriptionVerifyDelay: const Duration(milliseconds: 500));
    await pumpUntilDone(tester, BillingService().startAppWide());
    store.events.add([_purchase(PurchaseStatus.purchased)]);
    await tester.pump();
    await pumpUntilDone(tester, BillingService().stopAppWide());
    await settle(tester);
    expect(BillingService().status, null);
    expect(BillingService().canRetryVerification, false);
    expect(store.completed, isEmpty);
  });

  premiumTest('SessizKurtarmadaDogrulamaHatasi_KullaniciyaMesajGostermez_VeTamamlanmaz', (tester) async {
    await setUpFakeApi(subscriptionStatus: _status(), subscriptionVerifyStatus: 500);
    store.restored = [_purchase(PurchaseStatus.restored)];
    await pumpUntilDone(tester, BillingService().startAppWide());
    expect(BillingService().error, null);
    expect(store.completed, isEmpty);
    expect(BillingService().canRetryVerification, true);
  });

  /// NEDEN: Play hizmeti yokken kullanıcı çalışmayan bir satın alma butonuyla karşılaşmamalı.
  premiumTest('Mağaza kullanılamıyorsa açıklama ve tekrar dene görünür', (tester) async {
    store.available = false;
    await _open(tester);
    expect(find.text('Satın alma şu an kullanılamıyor'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.byKey(const Key('premium-buy')), findsNothing);
    store.available = true;
    await tester.tap(find.text('Tekrar dene'));
    await settle(tester);
    expect(find.text('Yıllık · Önerilen'), findsOneWidget);
  });

  /// NEDEN: Console ürünleri henüz yayınlanmamışsa boş mağaza da anlaşılır bir hata vermeli.
  premiumTest('Ürünler gelmediyse satın alma kullanılamıyor görünür', (tester) async {
    store.products = [];
    await _open(tester);
    expect(find.text('Satın alma şu an kullanılamıyor'), findsOneWidget);
  });

  /// NEDEN: Android denemenin fiyatını sıfır verir; ekranda deneme sonrası gerçek ücret gösterilmeli.
  premiumTest('İki plan Play fiyatı ve yedi günlük denemeyle listelenir', (tester) async {
    await _open(tester);
    expect(store.queriedIds, BillingService.productIds);
    expect(find.text('Aylık'), findsOneWidget);
    expect(find.text('Yıllık · Önerilen'), findsOneWidget);
    expect(find.text('7 gün ücretsiz, sonra ₺99,00/ay'), findsOneWidget);
    expect(find.text('7 gün ücretsiz, sonra ₺799,00/yıl'), findsOneWidget);
    expect(find.text('%33 tasarruf'), findsOneWidget);
    expect(find.text('Ücretsiz: 8 yatırım'), findsOneWidget);
    expect(find.text('Ücretsiz: 4 bütçe'), findsOneWidget);
    expect(find.text('Ücretsiz: 6 ekstre/ay'), findsOneWidget);
  });

  /// NEDEN: Denemeye uygun olmayan hesapta var olmayan bir deneme vaat edilmemeli.
  premiumTest('Deneme yoksa base planın biçimlenmiş fiyatı gösterilir', (tester) async {
    store.products = [
      ..._products(BillingService.premiumMonthly, '₺99,00', 99000000, trial: false),
      ..._products(BillingService.premiumYearly, '₺799,00', 799000000, trial: false),
    ];
    await _open(tester);
    expect(find.text('₺99,00/ay'), findsOneWidget);
    expect(find.text('₺799,00/yıl'), findsOneWidget);
    expect(find.textContaining('7 gün ücretsiz'), findsNothing);
  });

  /// NEDEN: Görünen deneme teklifi satın alınmalı ve Play satın alımı sunucu hesabına bağlamalı.
  premiumTest('Satın alma seçili ürün ve sunucunun accountToken değeriyle başlar', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('premium-buy')));
    await settle(tester);
    expect(store.bought.single.id, BillingService.premiumYearly);
    expect((store.bought.single as GooglePlayProductDetails).offerToken, 'premium_yearly-trial');
    expect(store.accountTokens.single, 'hesaba-ozel-sunucu-jetonu');
    expect(find.text('Premium üyesiniz'), findsNothing);
    expect(_verifyRequests(), isEmpty);
  });

  /// Uygulama oturumu başlatılmamış bağımsız ekran eski yaşam döngüsünü korur.
  /// startAppWide sonrası kapanış davranışı ayrı regresyon testiyle korunur.
  premiumTest('AppWide baslatilmamissa ekran kapaninca abonelik iptal edilir ve tekrar acilabilir', (tester) async {
    await _open(tester);
    expect(store.events.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(store.events.hasListener, isFalse);

    await _open(tester);
    expect(store.events.hasListener, isTrue);
    final purchase = _purchase(PurchaseStatus.purchased);
    store.events.add([purchase]);
    await settle(tester);
    expect(store.completed, [purchase]);
    expect(find.text('Premium üyesiniz'), findsOneWidget);
  });

  /// NEDEN: Yerel satın alma olayı premium yetkisi vermez; önce doğru jeton sunucuda doğrulanmalı.
  premiumTest('Purchased sunucuda doğrulanır tamamlanır ve premium üyelik gösterilir', (tester) async {
    await _open(tester);
    final purchase = _purchase(PurchaseStatus.purchased);
    store.events.add([purchase]);
    await settle(tester);
    expect(fakeApiBodies['/api/subscription/verify'], {
      'productId': BillingService.premiumYearly, 'purchaseToken': 'play-satin-alma-jetonu',
    });
    expect(store.completed, [purchase]);
    expect(find.text('Premium üyesiniz'), findsOneWidget);
    expect(find.byKey(const Key('plan-premium_yearly')), findsNothing);
  });

  /// NEDEN: Sunucu reddederse acknowledgement yapılmamalı; hata kullanıcıya aynen ulaşmalı.
  premiumTest('Doğrulama 400 dönerse tamamlanmaz ve sunucunun mesajı gösterilir', (tester) async {
    await setUpFakeApi(subscriptionStatus: _status(), subscriptionVerifyStatus: 400,
        subscriptionVerifyResult: {'message': 'Bu satın alma başka bir hesaba bağlı.'});
    await _open(tester);
    store.events.add([_purchase(PurchaseStatus.purchased)]);
    await settle(tester);
    expect(store.completed, isEmpty);
    expect(find.text('Bu satın alma başka bir hesaba bağlı.'), findsOneWidget);
    expect(find.text('Premium üyesiniz'), findsNothing);
  });

  /// NEDEN: Geçici doğrulama hatası yeni bir ödeme başlatmadan aynı satın alımla giderilebilmeli.
  premiumTest('Doğrulama tekrar denenince aynı jeton tamamlanır', (tester) async {
    await setUpFakeApi(subscriptionStatus: _status(), subscriptionVerifyStatus: 502,
        subscriptionVerifyResult: {'message': 'Play doğrulaması geçici olarak kullanılamıyor.'});
    await _open(tester);
    final purchase = _purchase(PurchaseStatus.purchased);
    store.events.add([purchase]);
    await settle(tester);
    expect(store.completed, isEmpty);
    await setUpFakeApi(subscriptionStatus: _status(), subscriptionVerifyResult: _status(premium: true));
    await tester.ensureVisible(find.text('Tekrar dene'));
    await tester.tap(find.text('Tekrar dene'));
    await settle(tester);
    expect(store.completed, [purchase]);
    expect(store.bought, isEmpty);
    expect(fakeApiBodies['/api/subscription/verify']['purchaseToken'], 'play-satin-alma-jetonu');
    expect(find.text('Premium üyesiniz'), findsOneWidget);
  });

  /// NEDEN: Bekleyen ödemeden henüz doğrulanabilir bir satın alma veya premium yetkisi doğmaz.
  premiumTest('Pending ödeme bekleniyor gösterir ve verify çağırmaz', (tester) async {
    await _open(tester);
    store.events.add([_purchase(PurchaseStatus.pending)]);
    await settle(tester);
    expect(find.text('Ödeme bekleniyor'), findsOneWidget);
    expect(_verifyRequests(), isEmpty);
    expect(store.completed, isEmpty);
    await tester.tap(find.byKey(const Key('premium-buy')));
    expect(store.bought, isEmpty);
    store.events.add([_purchase(PurchaseStatus.purchased)]);
    await settle(tester);
    expect(find.text('Premium üyesiniz'), findsOneWidget);
  });

  /// NEDEN: Başka cihazda başlatılan bekleyen ödeme de sunucu durumundan görünmeli.
  premiumTest('Sunucunun purchasePending alanı ödeme bekleniyor gösterir', (tester) async {
    await setUpFakeApi(subscriptionStatus: _status(pending: true));
    await _open(tester);
    expect(find.text('Ödeme bekleniyor'), findsOneWidget);
    expect(_verifyRequests(), isEmpty);
  });

  /// NEDEN: Mevcut premium üyeye ikinci abonelik satılmamalı ve yenileme tarihi açıklanmalı.
  premiumTest('Premium kullanıcı plan yerine üyelik ve yenileme bilgisi görür', (tester) async {
    final opened = <Uri>[];
    linkLauncher = (uri) async { opened.add(uri); return true; };
    addTearDown(resetLinkLauncherForTest);
    await setUpFakeApi(subscriptionStatus: _status(premium: true));
    await _open(tester);
    expect(find.text('Premium üyesiniz'), findsOneWidget);
    expect(find.text('Yenileme tarihi: 04.11.2026'), findsOneWidget);
    expect(find.text('Aylık'), findsNothing);
    expect(find.byKey(const Key('premium-buy')), findsNothing);
    await tester.tap(find.text('Aboneliği yönet'));
    await settle(tester);
    expect(opened.single.toString(), abonelikYonetimUrl);
    expect(find.text('Aboneliği yönet'), findsOneWidget);
    expect(find.text('Abonelikleri yönet'), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });

  /// NEDEN: Otomatik yenileme kapalıysa tarih bir sonraki tahsilat gibi sunulmamalı.
  premiumTest('Yenilenmeyen premium üyelikte bitiş tarihi gösterilir', (tester) async {
    await setUpFakeApi(subscriptionStatus: _status(premium: true, renewing: false));
    await _open(tester);
    expect(find.text('Bitiş tarihi: 04.11.2026'), findsOneWidget);
  });

  /// NEDEN: Play penceresi açılırken çift dokunuş iki satın alma isteği oluşturmamalı.
  premiumTest('Satın alma sürerken ikinci basış ikinci buy çağırmaz', (tester) async {
    await _open(tester);
    final button = find.byKey(const Key('premium-buy'));
    await tester.tap(button);
    await tester.tap(button);
    await settle(tester);
    expect(store.bought.length, 1);
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
    expect(find.descendant(of: button, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
  });

  /// NEDEN: Play iptali hata değildir; kullanıcı daha sonra tekrar satın alabilmeli.
  premiumTest('İptal sessizdir ve satın alma butonu tekrar açılır', (tester) async {
    await _open(tester);
    await tester.tap(find.byKey(const Key('premium-buy')));
    store.events.add([_purchase(PurchaseStatus.canceled)]);
    await settle(tester);
    expect(_verifyRequests(), isEmpty);
    expect(tester.widget<ElevatedButton>(find.byKey(const Key('premium-buy'))).onPressed, isNotNull);
  });

  /// NEDEN: Geri yüklenen satın alımlar da sunucu doğrulaması olmadan premium sayılmamalı.
  premiumTest('Geri yükle mağazayı çağırır ve restored olayını doğrular', (tester) async {
    await _open(tester);
    final purchase = _purchase(PurchaseStatus.restored);
    store.restored = [purchase];
    await tester.ensureVisible(find.text('Satın alımları geri yükle'));
    await tester.tap(find.text('Satın alımları geri yükle'));
    await settle(tester);
    expect(store.restoreCalls, 1);
    expect(_verifyRequests().length, 1);
    expect(store.completed, [purchase]);
    expect(find.text('Premium üyesiniz'), findsOneWidget);
  });

  /// NEDEN: Sunucu premium vermediyse başarılı HTTP yanıtı bile yerel yetki yükseltmemeli.
  premiumTest('Başarılı verify premium false döndürürse üyelik açılmaz', (tester) async {
    await setUpFakeApi(subscriptionStatus: _status(), subscriptionVerifyResult: _status());
    await _open(tester);
    store.events.add([_purchase(PurchaseStatus.purchased)]);
    await settle(tester);
    expect(store.completed.length, 1);
    expect(find.text('Premium üyesiniz'), findsNothing);
  });

  /// NEDEN: Daha önce tamamlanmış satın alım tekrar acknowledge edilmemeli.
  premiumTest('pendingCompletePurchase false ise yalnızca sunucuda doğrulanır', (tester) async {
    await _open(tester);
    store.events.add([_purchase(PurchaseStatus.restored, complete: false)]);
    await settle(tester);
    expect(_verifyRequests().length, 1);
    expect(store.completed, isEmpty);
    expect(find.text('Premium üyesiniz'), findsOneWidget);
  });

  /// NEDEN: Profil satın alma ekranına doğrudan erişim sağlamalı.
  premiumTest('Profildeki Premium satırı PremiumScreen açar', (tester) async {
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Premium'), 200);
    await tester.tap(find.text('Premium'));
    await settle(tester);
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(find.text('Wallet Mark Premium'), findsOneWidget);
  });

  /// NEDEN: Profildeki aktif etiketi yalnızca sunucudaki premium durumunu yansıtmalı.
  premiumTest('Premium kullanıcının profil satırında Aktif görünür', (tester) async {
    await setUpFakeApi(subscriptionStatus: _status(premium: true));
    await tester.pumpWidget(testApp(const ProfileScreen()));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Premium'), 200);
    expect(find.text('Aktif'), findsOneWidget);
  });

  /// NEDEN: Açık ve koyu temada küçük ekran da taşma veya çizim hatası üretmemeli.
  premiumTest('Premium ekranı açık ve koyu temada hatasız çizilir', (tester) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(testApp(const PremiumScreen(), theme: theme));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Wallet Mark Premium'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
