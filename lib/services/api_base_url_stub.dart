/// Default API base URL for platforms without dart:io (web).
/// The deployed backend URL is injected via --dart-define=API_BASE_URL.
String resolveDefaultBaseUrl() => const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:3000',
    );
