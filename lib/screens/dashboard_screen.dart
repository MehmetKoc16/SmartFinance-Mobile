import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/accounts_overview.dart';
import '../widgets/upcoming_payments_card.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/constants/category_style.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../core/utils/formatters.dart';
import '../core/utils/review_helpers.dart';
import '../services/api_service.dart';
import '../services/amount_privacy.dart';
import '../services/account_service.dart';
import '../services/recurring_payment_service.dart';
import '../services/transaction_trash.dart';
import '../widgets/transaction_card.dart';
import 'category_detail_screen.dart';
import 'notifications_screen.dart';

class _CategorySpend {
  final int? categoryId;
  final String name;
  final Color color;
  final IconData icon;
  final double amount;
  final double pct;
  const _CategorySpend({
    required this.categoryId,
    required this.name,
    required this.color,
    required this.icon,
    required this.amount,
    required this.pct,
  });
}

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onSeeAllTransactions;
  // Ust bardaki bildirim ve profil avatari eskiden hicbir seye baglanmiyordu
  // (duz Container, GestureDetector/InkWell yoktu) — gorsel olarak buton gibi
  // durup tiklaninca hicbir sey olmuyordu.
  final VoidCallback? onOpenProfile;
  const DashboardScreen({super.key, this.onSeeAllTransactions, this.onOpenProfile});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AmountPrivacyListener {
  bool _summaryFailed = false;
  bool _hasSummary = false;
  int _dashboardRequest = 0;
  Future<void>? _activeLoad;
  int? _activeYear, _activeMonth;
  // Ay bazlı önbelleğin hangi yıl/aya ait olduğunu tutar; hata durumunda
  // önceki değer yalnızca bu ay seçiliyse korunur.
  int? _dataYear, _dataMonth;
  Timer? _monthDebounce;
  bool _reloadPending = false;
  bool _hasLoadedDashboard = false;
  bool _errorVisible = false;
  bool _recentFailed = false;
  bool _hasRecentTransactions = false;
  double _totalIncome = 0;
  double _totalExpense = 0;
  double? _balanceChangePct;
  List<dynamic> _recentTransactions = [];
  // Ayin tum harcama kategorileri (buyukten kucuge); kartta ilk 4'u gosterilir,
  // "Tum kategoriler" ile hepsi acilir.
  List<_CategorySpend> _topSpendCats = [];
  bool _tumKategoriler = false;
  Map<int, String> _categoryMap = {};
  String _userName = '';
  bool _isLoading = true;
  int _unreadNotifications = 0;

  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    TransactionTrash.changes.addListener(_loadDashboardData);
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadDashboardData();
  }

  @override
  void dispose() {
    _monthDebounce?.cancel();
    TransactionTrash.changes.removeListener(_loadDashboardData);
    super.dispose();
  }

  void _changeMonth(int direction) {
    // Başlık hemen güncellenir; hızlı ay değişiminde 429 hız sınırını aşmamak
    // için istek 350 ms gecikmeli olarak yalnız son seçilen ay için atılır.
    setState(() {
      _selectedMonth += direction;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
    _monthDebounce?.cancel();
    _monthDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _loadDashboardData(includeStatic: false);
    });
  }

  // Sadece < > okuyla ay degistirmek, orn. 14 ay geriye gitmek icin 14 kez
  // tiklama gerektiriyordu — kullanici geri bildiriminde takvimden dogrudan
  // ay/yil secebilmek istedi.
  Future<void> _pickMonth() async {
    // Tema override'i yok: ColorScheme.dark acik temada beyaz uzerine beyaz yazi yapiyordu.
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_selectedYear, _selectedMonth),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedYear = picked.year;
      _selectedMonth = picked.month;
    });
    _monthDebounce?.cancel();
    _loadDashboardData(includeStatic: false);
  }

  bool get _isDataForSelectedMonth =>
      _dataYear == _selectedYear && _dataMonth == _selectedMonth;

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedYear == now.year && _selectedMonth == now.month;
  }

  String get _initials => nameInitials(_userName);

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 6) return 'İyi geceler,';
    if (hour < 12) return 'Günaydın,';
    if (hour < 18) return 'İyi günler,';
    return 'İyi akşamlar,';
  }

  Future<void> _refreshDashboard() async {
    // Kartları ekranda tut: dinleyiciye ek olarak initState isteği oluşmasın.
    AccountService.notifyChanged();
    RecurringPaymentService.notifyChanged();
    await _loadDashboardData(showLoading: false);
  }

  Future<void> _loadDashboardData({
    bool showLoading = true,
    bool includeStatic = true,
  }) async {
    _monthDebounce?.cancel();
    // Aynı ayın dinleyici isteği yenilemenin sonucunu/hatasını yutmamalı;
    // ancak yükleme sürerken veri değişmiş olabileceği için tek bir bekleyen
    // yeniden yükleme işaretlenir ve çağıran en güncel veri gelene kadar bekler.
    // Ay değişiminde yeni istek hemen başlar; eski yanıtın kimlik denetimi kalır.
    final year = _selectedYear, month = _selectedMonth;
    Future<void> current;
    final active = _activeLoad;
    if (active != null && _activeYear == year && _activeMonth == month) {
      _reloadPending = true;
      current = active;
    } else {
      _reloadPending = false;
      _activeYear = year;
      _activeMonth = month;
      late final Future<void> load;
      load = _fetchDashboardData(
        showLoading: showLoading,
        includeStatic: includeStatic,
      ).whenComplete(() {
        if (identical(_activeLoad, load)) {
          _activeLoad = null;
          if (_reloadPending) {
            _reloadPending = false;
            if (mounted) {
              _loadDashboardData(
                showLoading: false,
                includeStatic: includeStatic,
              );
            }
          }
        }
      });
      _activeLoad = load;
      current = load;
    }

    while (true) {
      await current;
      final next = _activeLoad;
      if (next == null ||
          identical(next, current) ||
          _activeYear != year ||
          _activeMonth != month) {
        break;
      }
      current = next;
    }
  }

  Future<void> _fetchDashboardData({
    required bool showLoading,
    bool includeStatic = true,
  }) async {
    if (!mounted) return;
    final request = ++_dashboardRequest;
    final year = _selectedYear, month = _selectedMonth;
    bool current() => mounted && request == _dashboardRequest &&
        year == _selectedYear && month == _selectedMonth;
    // Yenilemede kartları söküp yeniden yaratmak onların verisini de siler.
    if (showLoading && !_hasLoadedDashboard) {
      setState(() => _isLoading = true);
    }

    try {
      final prevMonth = month == 1 ? 12 : month - 1;
      final prevYear = month == 1 ? year - 1 : year;

      // Aydan bağımsız uçlar (/auth/me, /category, /notification/unread-count)
      // yalnızca ilk yükleme, yenileme ve dinleyicilerde çağrılır; ay
      // değişiminde tekrar istenmez.
      final results = await Future.wait([
        ApiService.authenticatedGet('/transaction/summary/$year/$month'),
        ApiService.authenticatedGet('/transaction/summary/$prevYear/$prevMonth'),
        ApiService.authenticatedGet('/transaction/filter?page=1&pageSize=5'),
        ApiService.authenticatedGet(
          '/transaction/category-summary/$year/$month?type=2',
        ),
        if (includeStatic) ...[
          ApiService.authenticatedGet('/auth/me'),
          ApiService.authenticatedGet('/category'),
          ApiService.authenticatedGet('/notification/unread-count'),
        ],
      ]);

      if (!current()) return;
      final summary = results[0];
      final prevSummary = results[1];
      final recent = results[2];
      final monthExpenses = results[3];
      final me = includeStatic ? results[4] : null;
      final categories = includeStatic ? results[5] : null;
      final unread = includeStatic ? results[6] : null;
      final meOk = includeStatic &&
          me is Map && !me.containsKey('error') && me['fullName'] is String;
      final recentOk =
          recent is Map && !recent.containsKey('error') && recent['items'] is List;
      final unreadOk = includeStatic &&
          unread is Map && !unread.containsKey('error') && unread['count'] is int;
      // Önceki ayın hatası yalnız karşılaştırmayı kaldırır (mevcut davranış).
      final failed = !validSummary(summary) ||
          [
            if (includeStatic) ...[me, categories, unread],
            recent,
            monthExpenses,
          ].any((r) => r is Map && r.containsKey('error'));

      if (categories is List) {
        _categoryMap = {for (var c in categories) c['id'] as int: c['name'] as String};
      }

      // Koruma kuralı yalnızca önbellekteki veri şu an yüklenen yıl/aya
      // aitse uygulanır; farklı bir aya geçildiğinde eski ayın rakamları
      // yeni başlık altında tutulmaz.
      final sameMonth = _dataYear == year && _dataMonth == month;
      final summaryOk = validSummary(summary);
      final income = summaryOk
          ? (summary['totalIncome'] as num).toDouble()
          : (sameMonth ? _totalIncome : 0.0);
      final expense = summaryOk
          ? (summary['totalExpense'] as num).toDouble()
          : (sameMonth ? _totalExpense : 0.0);
      final net = income - expense;

      final prevOk = validSummary(prevSummary);
      final prevIncome = prevOk ? (prevSummary['totalIncome'] as num).toDouble() : 0.0;
      final prevExpense = prevOk ? (prevSummary['totalExpense'] as num).toDouble() : 0.0;
      final prevNet = prevIncome - prevExpense;
      final changePct = !summaryOk || !prevOk || prevNet == 0 ? null : ((net - prevNet) / prevNet.abs()) * 100;

      final rows = monthExpenses is List ? monthExpenses : const [];
      final maxSpend = rows.isEmpty ? 1.0 : (rows.first['total'] as num).toDouble();
      final topSpendCats = rows.map((row) {
        final name = row['categoryId'] == null ? 'Kategorisiz' : row['categoryName'] as String;
        final amount = (row['total'] as num).toDouble();
        final style = CategoryStyles.of(name);
        return _CategorySpend(
          categoryId: row['categoryId'] as int?, name: name,
          color: style.color, icon: style.icon, amount: amount,
          pct: maxSpend == 0 ? 0 : amount / maxSpend * 100,
        );
      }).toList();

      if (current()) {
        setState(() {
          _dataYear = year;
          _dataMonth = month;
          _summaryFailed = !summaryOk;
          if (summaryOk) {
            _hasSummary = true;
          } else if (!sameMonth) {
            _hasSummary = false;
          }
          if (meOk) _userName = me['fullName'] as String;
          _totalIncome = income;
          _totalExpense = expense;
          _balanceChangePct = changePct;
          _recentFailed = !recentOk;
          if (recentOk) {
            _recentTransactions = recent['items'] as List;
            _hasRecentTransactions = true;
          } else if (!sameMonth) {
            _recentTransactions = [];
            _hasRecentTransactions = false;
          }
          if (monthExpenses is List) {
            _topSpendCats = topSpendCats;
            if (!sameMonth) _tumKategoriler = false;
          } else if (!sameMonth) {
            _topSpendCats = [];
            _tumKategoriler = false;
          }
          if (unreadOk) _unreadNotifications = unread['count'] as int;
          _hasLoadedDashboard = true;
          _isLoading = false;
        });
        if (failed) _showSummaryError();
      }
    } catch (e) {
      if (current()) {
        final sameMonth = _dataYear == year && _dataMonth == month;
        setState(() {
          _isLoading = false;
          _summaryFailed = true;
          _recentFailed = true;
          _hasLoadedDashboard = true;
          _balanceChangePct = null;
          if (!sameMonth) {
            _dataYear = year;
            _dataMonth = month;
            _hasSummary = false;
            _totalIncome = 0;
            _totalExpense = 0;
            _topSpendCats = [];
            _tumKategoriler = false;
            _recentTransactions = [];
            _hasRecentTransactions = false;
          }
        });
        _showSummaryError();
      }
    }
  }

  void _showSummaryError() {
    if (_errorVisible) return;
    _errorVisible = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Veriler yüklenemedi. Tekrar deneyin.')),
    ).closed.then((_) => _errorVisible = false);
  }

  String _getCategoryName(dynamic transaction) {
    final catId = transaction['categoryId'];
    if (catId != null && _categoryMap.containsKey(catId)) {
      return _categoryMap[catId]!;
    }
    return '';
  }

  /// Kategorinin secili aydaki ozeti ve islemleri (salt okunur ekran).
  void _kategoriyiAc(_CategorySpend c) {
    if (c.categoryId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryDetailScreen(
          categoryId: c.categoryId!,
          categoryName: c.name,
          year: _selectedYear,
          month: _selectedMonth,
        ),
      ),
    );
  }

  String _formatDay(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final d = DateTime(date.year, date.month, date.day);
      if (d == today) return 'Bugün';
      if (d == yesterday) return 'Dün';
      return DateFormat('d MMMM', 'tr_TR').format(date);
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : RefreshIndicator(
                onRefresh: _refreshDashboard,
                color: t.brand,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst karşılama
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_greeting, style: TextStyle(color: t.textSec, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                _userName.isNotEmpty ? _userName : 'Kullanıcı',
                                style: jakarta(fontSize: 18, fontWeight: FontWeight.w600, color: t.text),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                key: const Key('amount-privacy-toggle'),
                                tooltip: AmountPrivacy.gizli.value ? 'Tutarları göster' : 'Tutarları gizle',
                                onPressed: AmountPrivacy.toggle,
                                icon: Icon(AmountPrivacy.gizli.value ? LucideIcons.eyeOff : LucideIcons.eye,
                                  color: t.text, size: 18),
                              ),
                              GestureDetector(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                  );
                                  // Bildirim ekraninda okundu isaretlenmis olabilir —
                                  // zildeki rozet sayisi guncel kalsin diye tazele.
                                  if (mounted) _loadDashboardData();
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                        color: t.card,
                                        border: Border.all(color: t.border),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(LucideIcons.bell, color: t.text, size: 18),
                                    ),
                                    if (_unreadNotifications > 0)
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          constraints: const BoxConstraints(minWidth: 16),
                                          decoration: BoxDecoration(color: t.red, borderRadius: BorderRadius.circular(8)),
                                          child: Text(
                                            _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: widget.onOpenProfile,
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: t.brandSoft, shape: BoxShape.circle),
                                  child: Text(
                                    _initials,
                                    style: jakarta(fontSize: 14, fontWeight: FontWeight.w700, color: t.brand),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Ay seçici
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _monthNavButton(t, LucideIcons.chevronLeft, () => _changeMonth(-1)),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _pickMonth,
                                child: SizedBox(
                                  width: 110,
                                  child: Text(
                                    DateFormat('MMMM yyyy', 'tr_TR').format(DateTime(_selectedYear, _selectedMonth)),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              _monthNavButton(
                                  t, LucideIcons.chevronRight, _isCurrentMonth ? null : () => _changeMonth(1)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Bakiye kartı — gradient hero
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [t.brand, t.brandDeep],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Bu Ayki Bakiye',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                            const SizedBox(height: 8),
                            Text(
                              !_isDataForSelectedMonth || (_summaryFailed && !_hasSummary)
                                  ? '—'
                                  : formatTRY(_totalIncome - _totalExpense),
                              style: jakarta(
                                  fontSize: 34, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.5),
                            ),
                            if (_isDataForSelectedMonth && _balanceChangePct != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _balanceChangePct! >= 0 ? LucideIcons.arrowUpRight : LucideIcons.arrowDownRight,
                                      color: Colors.white,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${_balanceChangePct! >= 0 ? '+' : ''}${_balanceChangePct!.toStringAsFixed(1)}% geçen aya göre',
                                      style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Gelir / Gider kartları
                      Row(
                        children: [
                          Expanded(
                            child: _summaryCard(
                              t,
                              'Gelir',
                              _totalIncome,
                              t.green,
                              t.greenSoft,
                              LucideIcons.arrowDownLeft,
                              !_isDataForSelectedMonth ||
                                      (_summaryFailed && !_hasSummary) ||
                                      (_totalIncome + _totalExpense) == 0
                                  ? 0
                                  : _totalIncome / (_totalIncome + _totalExpense),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _summaryCard(
                              t,
                              'Gider',
                              _totalExpense,
                              t.red,
                              t.redSoft,
                              LucideIcons.arrowUpRight,
                              !_isDataForSelectedMonth ||
                                      (_summaryFailed && !_hasSummary) ||
                                      (_totalIncome + _totalExpense) == 0
                                  ? 0
                                  : _totalExpense / (_totalIncome + _totalExpense),
                            ),
                          ),
                        ],
                      ),

                      const AccountsOverview(),
                      const UpcomingPaymentsCard(),
                      if (_isDataForSelectedMonth && _topSpendCats.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kategoriye Göre Harcama',
                                  style: TextStyle(color: t.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              ..._topSpendCats.take(_tumKategoriler ? _topSpendCats.length : 4).map((c) => InkWell(
                                    onTap: () => _kategoriyiAc(c),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(color: c.color, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 88,
                                          child: Text(
                                            c.name,
                                            style: TextStyle(color: t.text, fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(3),
                                            child: Container(
                                              height: 6,
                                              color: t.divider,
                                              child: FractionallySizedBox(
                                                alignment: Alignment.centerLeft,
                                                widthFactor: (c.pct / 100).clamp(0, 1),
                                                child: Container(color: c.color),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        SizedBox(
                                          width: 74,
                                          child: Text(
                                            formatTRY(c.amount, decimals: false),
                                            textAlign: TextAlign.right,
                                            style: TextStyle(color: t.textSec, fontSize: 12.5),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(LucideIcons.chevronRight, size: 15, color: t.textTert),
                                      ],
                                    ),
                                  ),
                                  )),
                              if (_topSpendCats.length > 4)
                                Center(
                                  child: TextButton(
                                    onPressed: () => setState(() => _tumKategoriler = !_tumKategoriler),
                                    child: Text(
                                      _tumKategoriler ? 'Daha az göster' : 'Tüm kategoriler (${_topSpendCats.length})',
                                      style: TextStyle(color: t.brand, fontSize: 12.5, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 28),

                      // Son İşlemler başlığı
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Son İşlemler', style: jakarta(fontSize: 15, fontWeight: FontWeight.w600, color: t.text)),
                          GestureDetector(
                            onTap: widget.onSeeAllTransactions,
                            child: Text('Tümünü Gör',
                                style: TextStyle(color: t.brand, fontSize: 13, fontWeight: FontWeight.w500)),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      if (!_isDataForSelectedMonth)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: t.brand),
                            ),
                          ),
                        )
                      else if (_recentTransactions.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              _recentFailed && !_hasRecentTransactions
                                  ? 'İşlemler yüklenemedi'
                                  : 'Henüz işlem yok\n+ butonuyla ilk işleminizi ekleyin',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: t.textSec, fontSize: 14),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: t.card,
                            border: Border.all(color: t.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < _recentTransactions.length; i++)
                                TransactionCard(
                                  description: _recentTransactions[i]['description'] ?? '',
                                  merchantName: _recentTransactions[i]['merchantName'],
                                  amount: (_recentTransactions[i]['amount'] ?? 0).toDouble(),
                                  type: _recentTransactions[i]['type'] ?? 2,
                                  categoryName: _getCategoryName(_recentTransactions[i]),
                                  date: _formatDay(_recentTransactions[i]['transactionDate']),
                                  showDivider: i != _recentTransactions.length - 1,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _monthNavButton(AppTokens t, IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return SizedBox(
      width: 30,
      height: 30,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: enabled ? t.textSec : t.textTert),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _summaryCard(
      AppTokens t, String title, double amount, Color color, Color softColor, IconData icon, double ratio) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: softColor, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(color: t.textSec, fontSize: 12.5, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            !_isDataForSelectedMonth || (_summaryFailed && !_hasSummary)
                ? '—'
                : formatTRY(amount),
            style: TextStyle(color: t.text, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1).toDouble(),
              minHeight: 4,
              backgroundColor: t.divider,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
