import 'package:flutter/material.dart';
import 'package:gympass/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gympass/core/theme/app_theme.dart';
import 'package:gympass/features/auth/presentation/sign_in_page.dart';

void main() {
  testWidgets('sign-in page renders phone step', (tester) async {
    // Default test viewport is 800x600 (desktop landscape). The sign-in page
    // is designed for a tall phone-like aspect ratio, so widen + lengthen the
    // surface to comfortably fit the display-size headline plus the CTA stack.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
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
    await tester.pumpAndSettle();
    // PillButton renders its label upper-cased.
    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('CONTINUE WITH GOOGLE'), findsOneWidget);
  });
}
