/// Single source of truth for the app version. Bump this when shipping a
/// new APK, and update releases/version.json to match - installed apps
/// compare themselves against it and prompt the user to update.
class AppVersion {
  static const String version = '1.0.1';
  static const int buildNumber = 2;

  static const String apkUrl =
      'https://merjohnpagente.github.io/spotify/SpotifyFY.apk';
  static const String updateCheckUrl =
      'https://merjohnpagente.github.io/spotify/version.json';
}
