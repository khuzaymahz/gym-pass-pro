class AppEnv {
  const AppEnv({
    required this.apiBaseUrl,
    required this.webBaseUrl,
    required this.googleOAuthClientId,
    required this.googleMapsKey,
    required this.appEnv,
  });

  final String apiBaseUrl;

  /// Public-web base URL — used for share links, deep-linkable
  /// referral codes, and any other URL the member would actually
  /// open in a browser. Distinct from `apiBaseUrl` (which serves
  /// JSON, not landing pages). Override at build time with
  /// `--dart-define=WEB_BASE_URL=https://gym-pass.net`.
  final String webBaseUrl;
  final String googleOAuthClientId;

  /// Google Cloud project key with **Static Maps API** enabled. Used
  /// by the explore page to fetch a single PNG preview instead of
  /// rendering a full Maps SDK widget — see `StaticMapUrl.build`.
  /// Pass via `--dart-define=GOOGLE_MAPS_KEY=...` at build time, or
  /// leave blank during scaffolding (helper renders a placeholder).
  final String googleMapsKey;

  /// Raw env string: `development`, `staging`, or `production`.
  /// Prefer the intent-named getters (`useMockAuth`, `isProduction`,
  /// `isStaging`) over this field at call sites — that way adding a
  /// fourth env value later is a single decision per intent, not a
  /// code search.
  final String appEnv;

  /// True only when the backend would return the dev OTP `1234`.
  /// Concretely: `appEnv == 'development'`. Both staging and
  /// production exercise the real OTP path (mock-SMS in staging
  /// still produces a *random* 4-digit code that the operator reads
  /// from `docker compose logs -f backend`).
  ///
  /// Used by:
  ///   - The OTP page's "Dev mode: use 1234" hint visibility.
  ///   - Any other dev-only fast-paths the auth flow chose to keep.
  bool get useMockAuth => appEnv == 'development';

  /// True only when shipping to production. Drives anything
  /// production-strict (e.g. hiding debug menus, refusing to talk
  /// to non-HTTPS API URLs).
  bool get isProduction => appEnv == 'production';

  /// True when the app is pointed at the staging stack
  /// (`stg-api.gym-pass.net`). Same network shape as production but
  /// real OTP path; the OTP code itself is in the backend logs.
  bool get isStaging => appEnv == 'staging';

  /// Back-compat alias. Old call sites read `env.isDev` to mean
  /// "use the mock-OTP fast path". Some of those call sites are
  /// genuinely "dev only" (e.g. visible debug chrome) — those
  /// should migrate to `useMockAuth` or `isProduction` over time.
  /// Kept as a property so existing code compiles unchanged.
  @Deprecated('Prefer useMockAuth / isProduction / isStaging')
  bool get isDev => appEnv == 'development';

  // 10.0.2.2 is the Android emulator alias for the host machine.
  // On a real device with ADB reverse (tcp:8000) active, localhost:8000
  // is the correct address. Pass --dart-define=API_BASE_URL=... to
  // override for any other environment.
  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  static const _webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'https://gym-pass.net',
  );
  static const _googleClient = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue: '',
  );
  static const _googleMapsKey = String.fromEnvironment(
    'GOOGLE_MAPS_KEY',
    defaultValue: '',
  );
  /// Build-time env selector. Three legal values:
  ///   - `development` (default) — talks to local dev backend on
  ///     `http://10.0.2.2:8000`, dev OTP `1234` works.
  ///   - `staging` — talks to whatever `API_BASE_URL` resolves to,
  ///     typically `https://stg-api.gym-pass.net`. Real OTP path;
  ///     code is in backend logs because SMS is mocked.
  ///   - `production` — same shape as staging but talks to the
  ///     production API and expects real SMS delivery.
  ///
  /// Set via `--dart-define=APP_ENV=staging`.
  static const _appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const current = AppEnv(
    apiBaseUrl: _apiBaseUrl,
    webBaseUrl: _webBaseUrl,
    googleOAuthClientId: _googleClient,
    googleMapsKey: _googleMapsKey,
    appEnv: _appEnv,
  );
}
