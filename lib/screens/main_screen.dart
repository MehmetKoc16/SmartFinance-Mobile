import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/app_bottom_sheet.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'add_transaction_screen.dart';
import 'categories_screen.dart';
import 'profile_screen.dart';
import 'investments_screen.dart';
import 'pdf_import_screen.dart';
import '../services/push_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;

  late List<Widget> _pages;

  // Ortadaki FAB yuvasi (index 2) gercek bir sayfa degil, sadece "Ekle"
  // menusunu aciyor — kaydirilabilir sekme sirasindan cikarildi. Kullanici
  // geri bildiriminde Instagram'daki gibi sekmeler arasi kaydirma istendi:
  // Ana Sayfa -> Yatirimlar -> (FAB atlanir) -> Islemler -> Profil.
  static const List<int> _swipeableTabs = [0, 1, 3, 4];

  @override
  void initState() {
    super.initState();
    // Oturum acik ve kilit gecildi: telefona bildirim kaydi burada basliyor.
    PushService.start();
    _pageController = PageController(initialPage: _swipeableTabs.indexOf(_currentIndex));
    _pages = [
      DashboardScreen(
        key: UniqueKey(),
        onSeeAllTransactions: () => _goToTab(3),
        onOpenProfile: () => _goToTab(4),
      ),
      const InvestmentsScreen(),
      const SizedBox(),
      TransactionsScreen(key: UniqueKey()),
      const ProfileScreen(),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _refreshPages() {
    setState(() {
      _pages[0] = DashboardScreen(
        key: UniqueKey(),
        onSeeAllTransactions: () => _goToTab(3),
        onOpenProfile: () => _goToTab(4),
      );
      _pages[3] = TransactionsScreen(key: UniqueKey());
    });
  }

  // Geri tusu once bunu geri sarar; bosken Ana Sayfadayiz demektir ve ancak o
  // zaman uygulamadan cikilir. MainScreen yigindaki tek route oldugu icin bu
  // olmadan Android geri tusu her sekmede dogrudan uygulamayi kapatiyordu.
  final List<int> _tabHistory = [];

  void _recordTabChange(int tabIndex) {
    // Bir onceki sekmeye donmek yeni kayit eklemek yerine son kaydi siler —
    // ileri geri kaydirmak gecmisi sisirmesin.
    if (_tabHistory.isNotEmpty && _tabHistory.last == tabIndex) {
      _tabHistory.removeLast();
    } else {
      _tabHistory.add(_currentIndex);
    }
    _currentIndex = tabIndex;
  }

  // jumpToPage: animateToPage uzak sekmeye (Ana Sayfa -> Profil) giderken
  // aradaki sayfalari da kaydirarak geciyordu.
  void _goToTab(int tabIndex) {
    if (tabIndex == _currentIndex) return;
    setState(() => _recordTabChange(tabIndex));
    _jumpToTab(tabIndex);
  }

  void _jumpToTab(int tabIndex) {
    final page = _swipeableTabs.indexOf(tabIndex);
    if (page != -1 && _pageController.hasClients) {
      _pageController.jumpToPage(page);
    }
  }

  // jumpToPage da onPageChanged'i tetikler; o durumda _currentIndex zaten
  // guncel oldugu icin yalnizca kullanicinin kaydirmasi islenir.
  void _onPageChanged(int position) {
    final tabIndex = _swipeableTabs[position];
    if (tabIndex == _currentIndex) return;
    setState(() => _recordTabChange(tabIndex));
  }

  void _goBackTab() {
    final previous = _tabHistory.removeLast();
    setState(() => _currentIndex = previous);
    _jumpToTab(previous);
  }

  Future<bool> _confirmExit() async {
    final t = AppTokens.of(context);
    final cik = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Uygulamadan çıkılsın mı?', style: TextStyle(color: t.text, fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: TextStyle(color: t.textSec)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Çık', style: TextStyle(color: t.red, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return cik ?? false;
  }

  static const _tabs = [
    (icon: LucideIcons.house, label: 'Ana Sayfa'),
    (icon: LucideIcons.trendingUp, label: 'Yatırımlar'),
    null, // ortadaki FAB yuvası
    (icon: LucideIcons.list, label: 'İşlemler'),
    (icon: LucideIcons.user, label: 'Profil'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Scaffold(
      body: PopScope(
        // Hic kendiliginden kapanmiyor: gecmis varsa onceki sekmeye donuluyor,
        // Ana Sayfadaysa once soruluyor (test kullanicisi geri bildirimi).
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (_tabHistory.isNotEmpty) {
            _goBackTab();
            return;
          }
          if (await _confirmExit()) SystemNavigator.pop();
        },
        child: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          children: [_pages[0], _pages[1], _pages[3], _pages[4]],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          height: 66,
          decoration: BoxDecoration(
            color: t.navBg,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 32, offset: const Offset(0, 12))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_tabs.length, (index) {
              final tab = _tabs[index];
              if (tab == null) {
                return Transform.translate(
                  offset: const Offset(0, -15),
                  child: GestureDetector(
                    onTap: _showAddMenu,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: t.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.bg, width: 4),
                        boxShadow: [BoxShadow(color: t.brand.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: const Icon(LucideIcons.plus, color: Colors.white, size: 26),
                    ),
                  ),
                );
              }
              final isActive = index == _currentIndex;
              final color = isActive ? t.brand : t.textTert;
              return GestureDetector(
                // behavior belirtilmezse varsayilan deferToChild: yalnizca
                // Icon/Text'in kendi piksellerine tiklaninca calisir, ikisi
                // arasindaki bosluga veya SizedBox'in doldurmadigi kenarlara
                // basinca hicbir sey olmaz — "yaziya basinca geciyor sanki"
                // hissi buradan geliyordu. opaque, tum SizedBox alanini tek
                // parca dokunma hedefi yapiyor.
                behavior: HitTestBehavior.opaque,
                onTap: () => _goToTab(index),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 22, color: color),
                      const SizedBox(height: 3),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  void _showAddMenu() {
    final t = AppTokens.of(context);
    showAppBottomSheet(
      context: context,
      backgroundColor: t.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: t.textTert, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            Text('İşlem Ekle', style: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
            const SizedBox(height: 20),
            _buildAddOption(t, LucideIcons.squarePen, 'Elle Ekle', 'Gelir veya gider ekle', t.brand, onTap: () async {
              Navigator.pop(context);
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionScreen()));
              if (result == true) _refreshPages();
            }),
            const SizedBox(height: 12),
            _buildAddOption(t, LucideIcons.shapes, 'Kategoriler', 'Kategori ekle veya düzenle', t.brand, onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
            }),
            const SizedBox(height: 12),
            _buildAddOption(t, LucideIcons.fileText, 'PDF ile Ekle', 'Banka ekstresini içe aktar', t.amber, onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfImportScreen())).then((_) => _refreshPages());
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(AppTokens t, IconData icon, String title, String subtitle, Color color, {VoidCallback? onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: TextStyle(color: t.text, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: TextStyle(color: t.textSec, fontSize: 12)),
      trailing: Icon(LucideIcons.chevronRight, color: t.textTert),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: t.inputBg,
      onTap: onTap,
    );
  }
}
