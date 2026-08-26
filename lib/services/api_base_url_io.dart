import 'dart:io';

/// Default API base URL for native platforms (mobile/desktop).
String resolveDefaultBaseUrl() {
  if (Platform.isAndroid) return 'http://10.0.2.2:3000';
  return 'http://localhost:3000';
}
