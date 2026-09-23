// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_fy/auth/login_screen.dart';
import 'package:spotify_fy/theme.dart';

void main() {
  testWidgets('Login screen loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify that login screen loads
    expect(find.text('Spotify'), findsOneWidget);
    expect(find.text('Stream music ad-free with YouTube'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Theme has correct colors', (WidgetTester tester) async {
    expect(AppTheme.darkTheme.scaffoldBackgroundColor, SpotifyColors.primaryBackground);
    expect(AppTheme.darkTheme.primaryColor, SpotifyColors.primaryAccent);
    expect(SpotifyColors.primaryBackground, const Color(0xFF121212));
    expect(SpotifyColors.primaryAccent, const Color(0xFF1DB954));
  });
}
