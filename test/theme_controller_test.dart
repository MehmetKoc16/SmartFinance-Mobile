import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smartfinance_mobile/core/theme/theme_controller.dart';

void main() {
  group('ThemeController', () {
    test('Kayitli tercih yoksa varsayilan Sistem temasidir', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController();
      await Future.delayed(Duration.zero);

      expect(controller.mode, ThemeMode.system);
    });

    test('setMode hem state\'i hem SharedPreferences\'i gunceller', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController();
      await Future.delayed(Duration.zero);

      await controller.setMode(ThemeMode.dark);

      expect(controller.mode, ThemeMode.dark);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), 'dark');
    });

    test('Uygulama yeniden acildiginda kayitli tema geri yuklenir', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final controller = ThemeController();
      await Future.delayed(Duration.zero);

      expect(controller.mode, ThemeMode.light);
    });

    test('setMode degisikligi listener\'lara bildirir', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController();
      await Future.delayed(Duration.zero);

      var notified = false;
      controller.addListener(() => notified = true);

      await controller.setMode(ThemeMode.dark);

      expect(notified, isTrue);
    });
  });
}
