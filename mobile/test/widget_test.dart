import 'package:flutter/material.dart';
import 'package:gympass/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gympass/core/prefs/app_preferences.dart';
import 'package:gympass/core/theme/app_theme.dart';
import 'package:gympass/features/auth/presentation/sign_in_page.dart';

void main() {
  testWidgets('sign-in page renders phone step', (tester) async {
    // The entry chrome (EntryTopToggles) reads appPreferencesProvider /
    // sharedPreferencesProvider, both of which deliberately throw unless
    // overridden — main() seeds them from loadAppPreferences() before
    // runApp. Mirror that here with mock SharedPreferences + default prefs.
    // We deliberately do NOT call loadAppPreferences(): its secure_storage
    // migration read is a platform-channel call that never resolves under
    // the fake-async test clock and hangs the test.
    SharedPreferences.setMockInitialValues({});
    final shared = await SharedPreferences.getInstance();

    // Default test viewport is 800x600 (desktop landscape). The sign-in page
    // is designed for a tall phone-like aspect ratio, so widen + lengthen the
    // surface to comfortably fit the display-size headline plus the CTA stack.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWith(
            (ref) => AppPreferencesNotifier(shared, const AppPreferences()),
          ),
          sharedPreferencesProvider.overrideWithValue(shared),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(languageCode: 'en'),
          locale: const Locale('en'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const SignInPage(),
        ),
      ),
    );
    // The page's RadialGlow + Wordmark run infinite `.repeat()` animations,
    // so pumpAndSettle() would never settle (it times out). The CTA stack
    // renders on the first build, so a couple of bounded pumps are enough.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // PillButton renders its label upper-cased.
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
  });
}
