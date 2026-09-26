import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/pdf_import_screen.dart';

import 'helpers/test_app.dart';

Map<String, dynamic> _islem(String aciklama, {bool bakiyeTutmuyor = false}) => {
      'amount': 200.0,
      'description': aciklama,
      'merchantName': aciklama,
      'transactionDate': '2026-09-02T00:00:00',
      'type': 2,
      'categoryId': null,
      'categoryName': null,
      'isDuplicate': false,
      'balanceMismatch': bakiyeTutmuyor,
    };

void main() {
  tearDown(tearDownFakeApi);

  // Kucuk ekranli telefon (360x600 mantiksal piksel).
  void kucukTelefon(WidgetTester tester) {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1080, 1800);
    addTearDown(tester.view.reset);
  }

  Future<File> ornekDosya() async {
    final dosya = File('${Directory.systemTemp.createTempSync('ekstre').path}/ornek.pdf')
      ..writeAsBytesSync([37, 80, 68, 70]);
    addTearDown(() => dosya.parent.deleteSync(recursive: true));
    return dosya;
  }

  /// Regresyon (26.09.2026, test yazarken bulundu): dosya secim ekrani
  /// kaydirilamiyordu; kisa ekranda 45 piksel tasiyor, "Analiz Et" butonu
  /// ekranin disina itiliyordu.
  testWidgets('Kucuk ekranda dosya secim ekrani tasmaz', (tester) async {
    kucukTelefon(tester);
    await setUpFakeApi();
    final dosya = await ornekDosya();

    await tester.pumpWidget(testApp(PdfImportScreen(initialFilePath: dosya.path)));
    await settle(tester);

    expect(tester.takeException(), isNull);
  });

  /// Sunucudaki sutun tabanli ayristirici (26.09.2026) bakiye zinciri tutmayan
  /// satiri isaretliyor: tutar veya tur yanlis okunmus olabilir. Kullanici bunu
  /// ice aktarmadan once gormeli.
  testWidgets('Bakiyesi tutmayan islemde kullaniciya kontrol uyarisi gosterilir', (tester) async {
    kucukTelefon(tester);
    await setUpFakeApi(pdfParseResult: {
      'transactions': [_islem('MARKET'), _islem('ECZANE', bakiyeTutmuyor: true)],
      'bankName': 'Genel (sütun tabanlı)',
      'period': null,
      'totalIncome': 0,
      'totalExpense': 2,
      'duplicateCount': 0,
    });
    final dosya = await ornekDosya();

    await tester.pumpWidget(testApp(PdfImportScreen(initialFilePath: dosya.path)));
    await settle(tester);
    await tester.ensureVisible(find.text('Analiz Et'));
    await tester.tap(find.text('Analiz Et'));
    await settle(tester);

    expect(find.text('ECZANE'), findsOneWidget);
    expect(find.text('Tutarı kontrol edin'), findsOneWidget);
  });
}
