import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gympass/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/deep_link/deep_link_handler.dart';
import '../core/prefs/app_preferences.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

class GymPassApp extends ConsumerWidget {
  const GymPassApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    // Theme + locale are read inside `_DeepLinkBootstrap` below
    // (after the deep-link scope is in place) — the wrapping
    // ProviderScope only needs the router to plumb the deep-link
    // handler override. Reading prefs at the outer build would
    // leak a redundant watch.
    return ProviderScope(
      overrides: [
        deepLinkHandlerProvider.overrideWith(
          (ref) => DeepLinkHandler(router: router, ref: ref),
        ),
      ],
      child: const _DeepLinkBootstrap(),
    );
  }
}

class _DeepLinkBootstrap extends ConsumerWidget {
  const _DeepLinkBootstrap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final prefs = ref.watch(appPreferencesProvider);
    final lang = prefs.locale.languageCode;
    return DeepLinkScope(
      child: MaterialApp.router(
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
      ),
    );
  }
}
