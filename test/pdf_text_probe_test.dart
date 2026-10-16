import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/services/pdf_text_probe.dart';

Uint8List pdf(String body) => Uint8List.fromList(latin1.encode('%PDF-1.5\n$body\n%%EOF'));

void main() {
  test('Duz metinli PDF fontu bulunur', () async {
    expect(await pdfMetinKatmaniVarMi(pdf('1 0 obj << /Font 2 0 R >> endobj')), true);
  });
  test('Yalniz resim XObject iceren PDF metinsizdir', () async {
    expect(await pdfMetinKatmaniVarMi(pdf('1 0 obj << /Type /XObject /Subtype /Image >> endobj')), false);
  });
  test('FlateDecode nesne akisindaki font bulunur', () async {
    final compressed = ZLibEncoder().convert(latin1.encode('<< /Font 3 0 R >>'));
    expect(await pdfMetinKatmaniVarMi(pdf('1 0 obj << /Type /ObjStm /Filter /FlateDecode /Length ${compressed.length} >>\nstream\n${latin1.decode(compressed)}\nendstream\nendobj')), true);
  });
  test('Sifreli PDF bilinmiyor doner', () async {
    expect(await pdfMetinKatmaniVarMi(pdf('/Encrypt 2 0 R /Font')), null);
  });
  test('Bozuk baytlar cokmez', () async {
    expect(await pdfMetinKatmaniVarMi(Uint8List.fromList([0, 1, 255])), null);
    expect(await pdfMetinKatmaniVarMi(pdf('<< /Filter /FlateDecode >>\nstream\nbozuk\nendstream')), null);
  });
  test('Acma siniri asilirsa bilinmiyor doner', () async {
    final compressed = ZLibEncoder().convert(List.filled(8 * 1024 * 1024 + 1, 65));
    expect(await pdfMetinKatmaniVarMi(pdf('<< /Filter /FlateDecode /Length ${compressed.length} >>\nstream\n${latin1.decode(compressed)}\nendstream')), null);
  });
  test('Toplam acilmis veri 40 MB sinirini asarsa bilinmiyor doner', () async {
    final compressed = ZLibEncoder().convert(List.filled(8 * 1024 * 1024, 65));
    final stream = '<< /Filter /FlateDecode /Length ${compressed.length} >>\nstream\n${latin1.decode(compressed)}\nendstream\n';
    expect(await pdfMetinKatmaniVarMi(pdf(List.filled(6, stream).join())), null);
  });
}
