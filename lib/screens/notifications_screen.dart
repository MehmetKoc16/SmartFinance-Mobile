import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_tokens.dart';
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final result = await ApiService.authenticatedGet('/notification');
    if (!mounted) return;
    setState(() {
      _notifications = result is List ? result.cast<Map<String, dynamic>>() : [];
      _isLoading = false;
    });
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    if (notification['isRead'] == true) return;
    setState(() => notification['isRead'] = true);
    await ApiService.authenticatedPut('/notification/${notification['id']}/read', {});
  }

  Future<void> _markAllAsRead() async {
    final hasUnread = _notifications.any((n) => n['isRead'] != true);
    if (!hasUnread) return;
    setState(() {
      for (final n in _notifications) {
        n['isRead'] = true;
      }
    });
    await ApiService.authenticatedPut('/notification/read-all', {});
  }

  String _relativeTime(String? isoDate) {
    if (isoDate == null) return '';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return '';
    final diff = DateTime.now().toUtc().difference(date.isUtc ? date : date.toUtc());
    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dakika önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    final local = date.isUtc ? date.toLocal() : date;
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  IconData _iconFor(int type) {
    switch (type) {
      case 1: // BudgetExceeded
        return LucideIcons.circleAlert;
      default:
        return LucideIcons.bell;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final hasUnread = _notifications.any((n) => n['isRead'] != true);
    return Scaffold(
      appBar: AppBar(
        title: Text('Bildirimler', style: jakarta(fontSize: 18, fontWeight: FontWeight.w700, color: t.text)),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text('Tümünü okundu işaretle', style: TextStyle(color: t.brand, fontSize: 13)),
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: t.brand))
            : _notifications.isEmpty
                ? _buildEmptyState(t)
                : RefreshIndicator(
                    onRefresh: _loadData,
                    color: t.brand,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _buildNotificationCard(t, _notifications[i]),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmptyState(AppTokens t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.bellOff, size: 48, color: t.textTert),
            const SizedBox(height: 16),
            Text('Henüz bildirim yok', style: TextStyle(color: t.textSec, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              'Bütçe limitini aştığınızda burada göreceksiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textTert, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppTokens t, Map<String, dynamic> notification) {
    final isRead = notification['isRead'] == true;
    return GestureDetector(
      onTap: () => _markAsRead(notification),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.card,
          border: Border.all(color: isRead ? t.border : t.brand.withValues(alpha: 0.4)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: t.amberSoft, borderRadius: BorderRadius.circular(12)),
              child: Icon(_iconFor(notification['type'] as int? ?? 0), color: t.amber, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${notification['title'] ?? ''}',
                    style: TextStyle(color: t.text, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${notification['message'] ?? ''}',
                    style: TextStyle(color: t.textSec, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _relativeTime(notification['createdDate'] as String?),
                    style: TextStyle(color: t.textTert, fontSize: 11),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4, left: 6),
                decoration: BoxDecoration(color: t.brand, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
