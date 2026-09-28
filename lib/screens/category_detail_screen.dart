import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants/category_style.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../services/api_service.dart';
import '../widgets/transaction_card.dart';

/// Tek kategorinin aylik ozeti ve islemleri. Ana sayfadaki "Kategoriye Gore
/// Harcama" kartindan acilir; ay ileri geri degistirilebilir.
class CategoryDetailScreen extends StatefulWidget {
  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.year,
    required this.month,
  });

  final int categoryId;
  final String categoryName;
  final int year;
  final int month;

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

/// Bir ayin kategori verisi.
class _AyVerisi {
  const _AyVerisi({required this.islemler, required this.oncekiToplam, required this.butce});
  final List<Map<String, dynamic>> islemler;
  final double oncekiToplam;
  final Map<String, dynamic>? butce;

  double get toplam => islemler.fold(0.0, (t, i) => t + (i['amount'] as num).toDouble());
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  // Sunucu sayfa basina en fazla 100 islem donduruyor. Toplam dogru olsun diye
  // tum sayfalar cekiliyor; 20 sayfa (2.000 islem) bir ay icin fazlasiyla yeterli.
  static const _sayfaBoyutu = 100;
  static const _enFazlaSayfa = 20;

  late int _yil = widget.year;
  late int _ay = widget.month;
  _AyVerisi? _veri;
  bool _yukleniyor = true;
  bool _hata = false;

  // Ay hizli degistirilirse gec gelen eski cevap yenisinin ustune yazmasin.
  int _istekNo = 0;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  bool get _buAyVeyaSonrasi {
    final now = DateTime.now();
    return _yil > now.year || (_yil == now.year && _ay >= now.month);
  }

  void _ayDegistir(int yon) {
    final d = DateTime(_yil, _ay + yon);
    setState(() {
      _yil = d.year;
      _ay = d.month;
    });
    _yukle();
  }

  Future<void> _yukle() async {
    final no = ++_istekNo;
    setState(() {
      _yukleniyor = true;
      _hata = false;
    });

    final onceki = DateTime(_yil, _ay - 1);
    final sonuclar = await Future.wait([
      _tumIslemler(_yil, _ay),
      _tumIslemler(onceki.year, onceki.month),
      ApiService.authenticatedGet('/budget/status/$_yil/$_ay'),
    ]);
    if (!mounted || no != _istekNo) return;

    final bu = sonuclar[0] as List<Map<String, dynamic>>?;
    final gecen = sonuclar[1] as List<Map<String, dynamic>>?;
    final butceler = sonuclar[2];
    setState(() {
      _yukleniyor = false;
      if (bu == null) {
        _hata = true;
        return;
      }
      _veri = _AyVerisi(
        islemler: bu,
        oncekiToplam: (gecen ?? const []).fold(0.0, (t, i) => t + (i['amount'] as num).toDouble()),
        butce: butceler is List
            ? butceler.cast<Map<String, dynamic>>().where((b) => b['categoryId'] == widget.categoryId).firstOrNull
            : null,
      );
    });
  }

  /// Kategorinin o aydaki tum islemleri (yeniden eskiye); hata olursa null.
  Future<List<Map<String, dynamic>>?> _tumIslemler(int yil, int ay) async {
    final bas = DateTime(yil, ay, 1);
    final son = DateTime(yil, ay + 1, 1).subtract(const Duration(seconds: 1));
    final hepsi = <Map<String, dynamic>>[];
    for (var sayfa = 1; sayfa <= _enFazlaSayfa; sayfa++) {
      final cevap = await ApiService.authenticatedGet(
        '/transaction/filter?page=$sayfa&pageSize=$_sayfaBoyutu&categoryId=${widget.categoryId}'
        '&startDate=${bas.toIso8601String()}&endDate=${son.toIso8601String()}',
      );
      if (cevap is! Map || cevap['items'] is! List) return null;
      final gelen = List<Map<String, dynamic>>.from(cevap['items'] as List);
      hepsi.addAll(gelen);
      final toplam = (cevap['totalCount'] as num?)?.toInt() ?? hepsi.length;
      if (gelen.isEmpty || hepsi.length >= toplam) break;
    }
    return hepsi;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final stil = CategoryStyles.of(widget.categoryName);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(title: Text(widget.categoryName)),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _yukle,
          color: t.brand,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _aySecici(t),
              const SizedBox(height: 14),
              if (_yukleniyor && _veri == null)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_hata)
                _hataKarti(t)
              else ...[
                _ozetKarti(t, stil, _veri!),
                const SizedBox(height: 20),
                Text('İşlemler', style: jakarta(fontSize: 15, fontWeight: FontWeight.w600, color: t.text)),
                const SizedBox(height: 10),
                _islemListesi(t, _veri!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _aySecici(AppTokens t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Önceki ay',
          onPressed: () => _ayDegistir(-1),
          icon: Icon(LucideIcons.chevronLeft, color: t.text),
        ),
        SizedBox(
          width: 150,
          child: Text(
            DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(_yil, _ay)),
            textAlign: TextAlign.center,
            style: TextStyle(color: t.text, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          tooltip: 'Sonraki ay',
          // Gelecek aylarda islem olmaz; bos ekrana gitmesin.
          onPressed: _buAyVeyaSonrasi ? null : () => _ayDegistir(1),
          icon: Icon(LucideIcons.chevronRight, color: _buAyVeyaSonrasi ? t.textTert : t.text),
        ),
      ],
    );
  }

  Widget _ozetKarti(AppTokens t, CategoryStyle stil, _AyVerisi v) {
    final gelirMi = v.islemler.isNotEmpty && v.islemler.first['type'] == 1;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: stil.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
                child: Icon(stil.icon, color: stil.color, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.categoryName,
                    style: TextStyle(color: t.textSec, fontSize: 13.5, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
              Text('${v.islemler.length} işlem', style: TextStyle(color: t.textSec, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 14),
          Text(formatTRY(v.toplam), style: jakarta(fontSize: 28, fontWeight: FontWeight.w700, color: t.text)),
          const SizedBox(height: 8),
          _degisim(t, v, gelirMi),
          if (v.butce != null) ...[
            const SizedBox(height: 16),
            _butce(t, v.butce!),
          ],
        ],
      ),
    );
  }

  Widget _degisim(AppTokens t, _AyVerisi v, bool gelirMi) {
    if (v.oncekiToplam == 0) {
      return Text('Geçen ay bu kategoride işlem yoktu.', style: TextStyle(color: t.textTert, fontSize: 12.5));
    }
    final yuzde = ((v.toplam - v.oncekiToplam) / v.oncekiToplam * 100).round();
    final artti = yuzde > 0;
    // Giderde artis kotu (kirmizi), gelirde iyi (yesil).
    final renk = yuzde == 0 ? t.textSec : (artti != gelirMi ? t.red : t.green);
    return Row(
      children: [
        Icon(artti ? LucideIcons.trendingUp : LucideIcons.trendingDown, size: 15, color: renk),
        const SizedBox(width: 6),
        Text('%${yuzde.abs()} geçen aya göre', style: TextStyle(color: renk, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _butce(AppTokens t, Map<String, dynamic> b) {
    final limit = (b['monthlyLimit'] as num).toDouble();
    final harcanan = (b['spent'] as num).toDouble();
    final oran = limit == 0 ? 0.0 : harcanan / limit;
    final renk = oran >= 1 ? t.red : (oran >= 0.8 ? t.amber : t.green);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Bütçe', style: TextStyle(color: t.textSec, fontSize: 12.5)),
            const Spacer(),
            Text(
              '${formatTRY(harcanan, decimals: false)} / ${formatTRY(limit, decimals: false)} · %${(oran * 100).round()}',
              style: TextStyle(color: renk, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: oran.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: t.divider,
            color: renk,
          ),
        ),
      ],
    );
  }

  Widget _islemListesi(AppTokens t, _AyVerisi v) {
    if (v.islemler.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text('Bu ay bu kategoride işlem yok.', style: TextStyle(color: t.textSec, fontSize: 13.5)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < v.islemler.length; i++)
            TransactionCard(
              description: v.islemler[i]['description'] ?? '',
              merchantName: v.islemler[i]['merchantName'],
              amount: (v.islemler[i]['amount'] ?? 0).toDouble(),
              type: v.islemler[i]['type'] ?? 2,
              categoryName: widget.categoryName,
              date: _gun(v.islemler[i]['transactionDate']),
              showDivider: i != v.islemler.length - 1,
            ),
        ],
      ),
    );
  }

  String _gun(String? tarih) {
    final d = tarih == null ? null : DateTime.tryParse(tarih);
    return d == null ? '' : DateFormat('d MMMM', 'tr_TR').format(d);
  }

  Widget _hataKarti(AppTokens t) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(LucideIcons.wifiOff, color: t.textTert, size: 36),
          const SizedBox(height: 12),
          Text('İşlemler yüklenemedi.', style: TextStyle(color: t.textSec, fontSize: 14)),
          const SizedBox(height: 12),
          TextButton(onPressed: _yukle, child: Text('Tekrar dene', style: TextStyle(color: t.brand))),
        ],
      ),
    );
  }
}
