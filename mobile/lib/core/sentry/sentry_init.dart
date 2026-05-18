import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../config/env.dart';

/// Sentry wiring for the mobile app.
///
/// `SENTRY_DSN` is a compile-time dart-define. Set it via
/// `--dart-define=SENTRY_DSN=https://…` at build time (or in
/// `dart_defines.prod.json`) to activate; leave empty and Sentry
/// init short-circuits so the SDK contributes zero runtime
/// overhead until operators flip it on.
///
/// Per CLAUDE.md §15 Sentry is "deferred until a real provider is
/// chosen" — this module is the wiring so flipping it on later is
/// one dart-define + APK rebuild, not a code change.
const _kSentryDsn = String.fromEnvironment('SENTRY_DSN');
const _kSentryRelease = String.fromEnvironment(
  'APP_RELEASE',
  defaultValue: 'gympass-mobile@0.1.0',
);

bool get _sentryEnabled => _kSentryDsn.isNotEmpty;

/// Run `runApp(...)` body inside a Sentry zone when the DSN is set;
/// otherwise run it directly so dev builds stay overhead-free.
Future<void> runWithSentry(FutureOr<void> Function() body) async {
  if (!_sentryEnabled) {
    await body();
    return;
  }
  await SentryFlutter.init(
    (options) {
      options.dsn = _kSentryDsn;
      options.environment = AppEnv.current.appEnv;
      options.release = _kSentryRelease;
      // Same staircase as the backend / Next surfaces: don't sample
      // dev (would noise a personal DSN), gradually sample
      // staging + prod.
      final env = AppEnv.current;
      options.tracesSampleRate = env.isProduction
          ? 0.05
          : env.isStaging
              ? 0.1
              : 0.0;
      // Off by default — the mobile app sees real user phone
      // numbers + emails; default scrubbing keeps them out of
      // Sentry's event payload unless the operator opts in.
      options.sendDefaultPii = false;
      // Mobile networks are flaky; let the SDK queue events to
      // disk and ship when connectivity returns instead of
      // dropping silently.
      options.maxBreadcrumbs = 80;
    },
    appRunner: body,
  );
}
