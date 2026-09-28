import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/screens/pdf_import_screen.dart';

import 'helpers/test_app.dart';

/// Regresyon (28.09.2026): onizlemede gidere gelir kategorisi (Maas)
/// secilebiliyordu. Sunucu artik turu uymayan kategoriyi atiyor; liste de
/// yalnizca uyan kategorileri sunmali, yoksa secim sessizce kaybolur.
void main() {
  tearDown(tearDownFakeApi);

  testWidgets('Gider satirinda yalnizca gider kategorileri secilebilir', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(1080, 2400);
    addTearDown(tester.view.reset);

    await setUpFakeApi(
      categories: [
        {'id': 1, 'name': 'Maaş', 'type': 1},
        {'id': 2, 'name': 'Fatura', 'type': 2},
      ],
      pdfParseResult: {
        'transactions': [
          {
            'amount': 0.37, 'description': 'MESAJ ÜCRETİ TUTARI', 'merchantName': 'MESAJ ÜCRETİ TUTARI',
            'transactionDate': '2026-09-18T00:00:00', 'type': 2, 'categoryId': null, 'categoryName': null,
            'isDuplicate': false, 'balanceMismatch': false,
          },
        ],
        'bankName': 'Genel (sütun tabanlı)',
        'duplicateCount': 0,
      },
    );
    final dosya = File('${Directory.systemTemp.createTempSync('ekstre').path}/ornek.pdf')
      ..writeAsBytesSync([37, 80, 68, 70]);
    addTearDown(() => dosya.parent.deleteSync(recursive: true));

    await tester.pumpWidget(testApp(PdfImportScreen(initialFilePath: dosya.path)));
    await settle(tester);
    await tester.ensureVisible(find.text('Analiz Et'));
    await tester.tap(find.text('Analiz Et'));
    await settle(tester);

    await tester.tap(find.text('Kategorisiz'));
    await settle(tester);

    expect(find.text('Fatura'), findsWidgets);
    expect(find.text('Maaş'), findsNothing);
  });
}
