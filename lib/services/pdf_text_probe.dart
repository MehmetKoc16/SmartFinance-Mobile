import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Hafif bir yoklama; tam PDF ayrıştırıcısı değildir. Belirsizlikte mevcut
/// sunucu ayrıştırıcısına bırakılır, metinsiz olduğu bilinen dosya yüklenmez.
Future<bool?> pdfMetinKatmaniVarMi(Uint8List bytes) async {
  const streamLimit = 8 * 1024 * 1024;
  const totalLimit = 40 * 1024 * 1024;
  try {
    final raw = latin1.decode(bytes);
    if (!raw.startsWith('%PDF-') || !raw.contains('%%EOF')) return null;
    if (raw.contains('/Encrypt')) return null;
    if (raw.contains('/Font')) return true;
    var total = 0;
    var found = false;
    final streams = RegExp(r'<<(.*?)>>\s*stream\r?\n', dotAll: true);
    var cursor = 0;
    while (true) {
      final matches = streams.allMatches(raw, cursor);
      if (matches.isEmpty) break;
      final match = matches.first;
      final dictionary = match.group(1)!;
      final end = raw.indexOf('endstream', match.end);
      if (end < 0) return null;
      cursor = end + 'endstream'.length;
      if (!dictionary.contains('/FlateDecode')) continue;
      // Doğrudan Length, sıkıştırılmış verideki tesadüfi endstream baytlarını
      // ayırır. Dolaylı Length için sonlandırıcıya kadar olan bölüm kullanılır.
      final lengthMatch = RegExp(r'/Length\s+(\d+)(?!\d)(?!\s+\d+\s+R)').firstMatch(dictionary);
      final length = lengthMatch == null ? null : int.parse(lengthMatch.group(1)!);
      var dataEnd = length == null ? end : match.end + length;
      if (dataEnd > bytes.length || dataEnd > end) return null;
      if (length == null) {
        if (dataEnd > match.end && bytes[dataEnd - 1] == 10) dataEnd--;
        if (dataEnd > match.end && bytes[dataEnd - 1] == 13) dataEnd--;
      }
      var expanded = 0;
      final output = BytesBuilder(copy: false);
      final sink = ZLibDecoder().startChunkedConversion(
        _ProbeSink((chunk) {
          expanded += chunk.length;
          total += chunk.length;
          if (expanded > streamLimit || total > totalLimit) {
            throw const FormatException('PDF expansion limit');
          }
          output.add(chunk);
        }),
      );
      // Küçük giriş parçalarıyla aç: sıkıştırma bombalarını sınırlara gelince kes.
      for (var start = match.end; start < dataEnd; start += 1024) {
        final stop = start + 1024 < dataEnd ? start + 1024 : dataEnd;
        sink.add(Uint8List.sublistView(bytes, start, stop));
      }
      sink.close();
      if (latin1.decode(output.takeBytes()).contains('/Font')) found = true;
    }
    if (raw.contains('/FlateDecode') && cursor == 0) return null;
    return found;
  } catch (_) {
    return null;
  }
}

class _ProbeSink implements Sink<List<int>> {
  _ProbeSink(this.onData);
  final void Function(List<int>) onData;
  @override
  void add(List<int> data) => onData(data);
  @override
  void close() {}
}
