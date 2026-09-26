import 'package:flutter/material.dart';

/// Uygulamadaki tum alt sayfalar buradan acilir.
///
/// showModalBottomSheet alt sistem cubugunu (3 tuslu gezinme) hesaba katmiyor;
/// sayfalar yalnizca klavye boslugunu (viewInsets) ekliyordu ve bazi
/// telefonlarda Kaydet butonu cubugun arkasinda kaliyordu. Arka plan cubugun
/// altina uzanmaya devam eder, yalnizca icerik yukari itilir. Klavye acikken
/// padding.bottom sifirlandigi icin klavye boslugu cift sayilmaz.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: backgroundColor,
    shape: shape,
    builder: (ctx) => SafeArea(top: false, child: builder(ctx)),
  );
}
