// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_fy/main.dart';
import 'package:spotify_fy/theme.dart';

void main() {
  testWidgets('Spotify app loads login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SpotifyApp());

    // Verify that login screen loads
    expect(find.text('Spotify Clone'), findsOneWidget);
    expect(find.text('Stream music ad-free with YouTube'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Theme has correct colors', (WidgetTester tester) async {
    await tester.pumpWidget(const SpotifyApp());

    final MaterialApp app = tester.widget(find.byType(MaterialApp));
    expect(app.theme?.scaffoldBackgroundColor, SpotifyColors.primaryBackground);
    expect(app.theme?.primaryColor, SpotifyColors.primaryAccent);
  });
}