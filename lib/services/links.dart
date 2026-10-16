import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const gizlilikUrl = 'https://walletmark.com.tr/gizlilik';
const abonelikYonetimUrl = 'https://play.google.com/store/account/subscriptions?package=com.walletmark.app';

Future<bool> _launch(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

@visibleForTesting
Future<bool> Function(Uri) linkLauncher = _launch;

@visibleForTesting
void resetLinkLauncherForTest() => linkLauncher = _launch;

Future<void> baglantiAc(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await linkLauncher(Uri.parse(url));
  } catch (_) {
    opened = false;
  }
  if (!context.mounted) return;
  if (!opened) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bağlantı açılamadı.')),
    );
  }
}
