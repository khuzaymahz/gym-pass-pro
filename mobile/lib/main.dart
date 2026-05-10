import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/prefs/app_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarContrastEnforced: false,
  ),);

  // Sync-load the splash-critical prefs (locale, themeMode) before
  // the first frame paints. SharedPreferences's getInstance() does
  // a one-time disk read (~5 ms cold) on the platform thread, so
  // this is fast enough to block runApp without a perceptible
  // delay — and it eliminates the previous ~50–800 ms window where
  // the splash painted in the default AR + dark while
  // secure_storage's Keystore-backed read was still in flight. The
  // ProviderScope override below seeds the notifier with the
  // loaded values so the first build of MaterialApp resolves the
  // correct theme and locale on its first invocation.
  final prefs = await loadAppPreferences();

  runApp(ProviderScope(
    overrides: [
      appPreferencesProvider.overrideWith(
        (ref) => AppPreferencesNotifier(prefs.shared, prefs.initial),
      ),
    ],
    child: const GymPassApp(),
  ),);
}
