import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gympass/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/prefs/app_preferences.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

class GymPassApp extends ConsumerWidget {
  const GymPassApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final prefs = ref.watch(appPreferencesProvider);
    final lang = prefs.locale.languageCode;
    // Both palettes are wired in — `themeMode` decides which one paints.
    // The system-overlay style needs to follow whichever palette is
    // active so the status bar icons stay readable, so we use a
    // `Builder` that reads `Theme.of(context).brightness` after the
    // theme resolves.
    return MaterialApp.router(
      title: 'GymPass',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(languageCode: lang),
      darkTheme: AppTheme.dark(languageCode: lang),
      themeMode: prefs.themeMode,
      routerConfig: router,
      locale: prefs.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness:
                isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarDividerColor: Colors.transparent,
            systemNavigationBarContrastEnforced: false,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
