import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartfinance_mobile/services/app_lock.dart';
import 'package:smartfinance_mobile/screens/biometric_lock_screen.dart';
import 'helpers/test_app.dart';

void main() {
  late DateTime now;
  late Completer<bool> auth;
  var loggedIn = true;
  var available = true;
  var authenticationCalls = 0;
  Future<void> open(WidgetTester tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: AppLock(
          navigatorKey: navigatorKey,
          now: () => now,
          hasSession: () async => loggedIn,
          available: () async => available,
          authenticate: () {
            authenticationCalls++;
            return auth.future;
          },
          child: const Scaffold(body: Text('Finans ekranı')),
        ),
      ),
    );
  }

  Future<void> resume(WidgetTester tester, int seconds) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(Duration(seconds: seconds));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
  }

  setUp(() {
    now = DateTime.utc(2026, 10, 18);
    auth = Completer<bool>();
    loggedIn = true;
    available = true;
    authenticationCalls = 0;
  });
  tearDown(() async {
    if (!auth.isCompleted) auth.complete(false);
    await Future<void>.value();
  });
  testWidgets('Altmis_SaniyedenKisa_ArkaPlan_Kilitlemez', (tester) async {
    await open(tester);
    await resume(tester, 59);
    expect(find.byType(BiometricLockScreen), findsNothing);
  });
  testWidgets('AltmisSaniyeSonra_KilitEkraniUsteGelir', (tester) async {
    await open(tester);
    await resume(tester, 61);
    expect(find.byType(BiometricLockScreen), findsOneWidget);
    expect(find.text('Finans ekranı'), findsNothing);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(BiometricLockScreen), findsOneWidget);
  });
  testWidgets('DogrulamaBasarili_KilitKalkar', (tester) async {
    await open(tester);
    await resume(tester, 61);
    auth.complete(true);
    // setUp'ta oluşturulan Future'ın gerçek async bölgesini de ilerlet.
    await pumpUntilDone(tester, auth.future);
    await settle(tester);
    expect(find.byType(BiometricLockScreen), findsNothing);
    expect(find.text('Finans ekranı'), findsOneWidget);
  });
  testWidgets('SistemDiyalogu_Suppress_IcindeKilitlenmez', (tester) async {
    await open(tester);
    final dialog = Completer<void>();
    final operation = AppLock.suppress(dialog.future);
    await resume(tester, 120);
    dialog.complete();
    await pumpUntilDone(tester, operation);
    await settle(tester);
    expect(find.byType(BiometricLockScreen), findsNothing);
    await resume(tester, 61);
    expect(find.byType(BiometricLockScreen), findsOneWidget);
  });
  testWidgets('OturumYokken_Kilitlenmez', (tester) async {
    loggedIn = false;
    await open(tester);
    await resume(tester, 61);
    expect(find.byType(BiometricLockScreen), findsNothing);
  });
  testWidgets('KilitAcikken_IkinciKilitAcilmaz', (tester) async {
    await open(tester);
    await resume(tester, 61);
    await resume(tester, 120);
    expect(
      find.byType(BiometricLockScreen, skipOffstage: false),
      findsOneWidget,
    );
    expect(authenticationCalls, 1);
  });
  testWidgets('BiyometriKullanilamiyorsa_Kilitlenmez', (tester) async {
    available = false;
    await open(tester);
    await resume(tester, 61);
    expect(find.byType(BiometricLockScreen), findsNothing);
    expect(authenticationCalls, 0);
  });
  testWidgets('TamAltmisSaniye_Kilitlemez', (tester) async {
    await open(tester);
    await resume(tester, 60);
    expect(find.byType(BiometricLockScreen), findsNothing);
  });
  testWidgets('Suppress_ArkaPlandaykenBiterse_DonusteKilitlemez', (
    tester,
  ) async {
    await open(tester);
    final dialog = Completer<void>();
    final operation = AppLock.suppress(dialog.future);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 120));
    dialog.complete();
    await pumpUntilDone(tester, operation);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(find.byType(BiometricLockScreen), findsNothing);
    await resume(tester, 61);
    expect(find.byType(BiometricLockScreen), findsOneWidget);
  });
}
