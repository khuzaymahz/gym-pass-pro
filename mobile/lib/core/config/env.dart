class AppEnv {
  const AppEnv({
    required this.apiBaseUrl,
    required this.webBaseUrl,
    required this.googleOAuthClientId,
    required this.googleMapsKey,
    required this.isDev,
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

  /// True while the real backend (`backend/`) doesn't exist yet. Lets the
  /// mobile app mock OTP requests locally instead of hammering a missing
  /// endpoint and surfacing `DioException` / `AUTH_OTP_LOCKED` to the user.
  final bool isDev;

  static const _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
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
  // Set APP_ENV=production at build time (--dart-define=APP_ENV=production)
  // to flip the client out of its offline/mock OTP path and talk to the
  // configured apiBaseUrl for real. Any other value keeps the dev mocks.
  static const _appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static const dev = AppEnv(
    apiBaseUrl: _apiBaseUrl,
    webBaseUrl: _webBaseUrl,
    googleOAuthClientId: _googleClient,
    googleMapsKey: _googleMapsKey,
    isDev: true,
  );

  static const prod = AppEnv(
    apiBaseUrl: _apiBaseUrl,
    webBaseUrl: _webBaseUrl,
    googleOAuthClientId: _googleClient,
    googleMapsKey: _googleMapsKey,
    isDev: false,
  );

  static AppEnv get current => _appEnv == 'production' ? prod : dev;
}
