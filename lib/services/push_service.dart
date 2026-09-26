import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../screens/notifications_screen.dart';
import 'api_service.dart';

/// Gelen bildirimin uygulamanin kullandigi kismi.
class PushPayload {
  const PushPayload({this.title, this.body, this.data = const {}});
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
}

/// Firebase Messaging'in uygulamanin kullandigi kismi. Testte yerel eklenti
/// calismadigi icin sahtesi verilir.
abstract class PushMessaging {
  Future<bool> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;
  Future<void> deleteToken();

  /// Uygulama kapaliyken bildirime dokunularak acildiysa o bildirim.
  Future<PushPayload?> getInitialMessage();
  Stream<PushPayload> get onMessageOpenedApp;

  /// Uygulama acikken gelen bildirim (Android bunu kendisi gostermez).
  Stream<PushPayload> get onForegroundMessage;
}

class FirebasePushMessaging implements PushMessaging {
  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  static PushPayload _payload(RemoteMessage m) =>
      PushPayload(title: m.notification?.title, body: m.notification?.body, data: m.data);

  @override
  Future<bool> requestPermission() async {
    final ayar = await _fm.requestPermission();
    return ayar.authorizationStatus == AuthorizationStatus.authorized ||
        ayar.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() => _fm.getToken();

  @override
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;

  @override
  Future<void> deleteToken() => _fm.deleteToken();

  @override
  Future<PushPayload?> getInitialMessage() async {
    final m = await _fm.getInitialMessage();
    return m == null ? null : _payload(m);
  }

  @override
  Stream<PushPayload> get onMessageOpenedApp => FirebaseMessaging.onMessageOpenedApp.map(_payload);

  @override
  Stream<PushPayload> get onForegroundMessage => FirebaseMessaging.onMessage.map(_payload);
}

/// Anlik bildirim (FCM) kaydi ve gelen bildirimlerin karsilanmasi.
///
/// Uygulama ici bildirimler (zil ikonu) her durumda calisir; push yalnizca
/// ek kanal. Firebase baslatilamazsa (Play Hizmetleri yok vb.) [enabled]
/// false kalir ve hicbir sey yapilmaz.
class PushService {
  PushService._();

  static bool enabled = false;
  static PushMessaging messaging = FirebasePushMessaging();

  /// MaterialApp'e baglanir; uygulama acikken gelen bildirim alt bantta gosterilir.
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  static String? _token;
  static final List<StreamSubscription<dynamic>> _abonelikler = [];

  /// Oturum acik ana ekran acildiginda cagrilir (girisin ve biyometrik
  /// kilidin ardindan). Tekrar cagrilmasi zararsiz.
  static Future<void> start() async {
    if (!enabled) return;
    await _durdurDinleyicileri();
    try {
      // Android 13+ bildirim izni. Reddedildiyse token kaydedilmez:
      // gosterilemeyecek bildirim icin sunucu bosuna istek atmasin.
      if (!await messaging.requestPermission()) return;

      final token = await messaging.getToken();
      if (token != null) await _kaydet(token);

      _abonelikler
        ..add(messaging.onTokenRefresh.listen(_kaydet))
        ..add(messaging.onMessageOpenedApp.listen(_acildi))
        ..add(messaging.onForegroundMessage.listen(_onPlandaGeldi));

      final ilk = await messaging.getInitialMessage();
      if (ilk != null) _acildi(ilk);
    } catch (e) {
      debugPrint('[Push] baslatilamadi: $e');
    }
  }

  /// Cikista, oturum token'lari silinmeden ONCE cagrilir: sunucudaki kayit
  /// kimlik dogrulamasi istiyor.
  static Future<void> stop() async {
    if (!enabled) return;
    await _durdurDinleyicileri();
    final token = _token;
    _token = null;
    try {
      if (token != null) {
        await ApiService.authenticatedPost('/devicetoken/unregister', {'token': token});
      }
      // Ayni telefonda baska hesapla giriste yeni token uretilsin.
      await messaging.deleteToken();
    } catch (e) {
      debugPrint('[Push] kayit silinemedi: $e');
    }
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    await _durdurDinleyicileri();
    _token = null;
    enabled = false;
    messaging = FirebasePushMessaging();
  }

  static Future<void> _durdurDinleyicileri() async {
    for (final a in _abonelikler) {
      await a.cancel();
    }
    _abonelikler.clear();
  }

  static Future<void> _kaydet(String token) async {
    _token = token;
    await ApiService.authenticatedPost('/devicetoken', {'token': token});
  }

  static void _acildi(PushPayload p) {
    if (p.data['type'] != 'notification') return;
    ApiService.navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  static void _onPlandaGeldi(PushPayload p) {
    final metin = [p.title, p.body].whereType<String>().join('\n');
    if (metin.isEmpty) return;
    scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(metin),
      duration: const Duration(seconds: 5),
      action: p.data['type'] == 'notification'
          ? SnackBarAction(label: 'Gör', onPressed: () => _acildi(p))
          : null,
    ));
  }
}
