import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotify_fy/auth/login_screen.dart';
import 'package:spotify_fy/auth/register_screen.dart';
import 'package:spotify_fy/main_screen.dart';
import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/services/api_client.dart';
import 'package:spotify_fy/services/token_store.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/toast.dart';

/// Periodically pings the backend /health endpoint to prevent Render free tier
/// from sleeping (idle >15min = cold start = 30-60s loading on next play).
void _startKeepAlive() {
  final baseUrl = ApiClient.defaultBaseUrl;
  if (baseUrl.isEmpty) return;
  final uri = Uri.parse('$baseUrl/health');
  Timer.periodic(const Duration(minutes: 8), (_) async {
    try {
      await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Best-effort — ignore failures
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Firebase powers "Continue with Google". If config is missing we
  // degrade gracefully - email/password login still works.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init skipped: $e');
  }
  // Keep Render server alive — ping every 8 min so it never sleeps
  _startKeepAlive();
  runApp(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(TokenStore(prefs)),
      ],
      child: const SpotifyApp(),
    ),
  );
}

class SpotifyApp extends StatelessWidget {
  const SpotifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spotify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scaffoldMessengerKey: scaffoldMessengerKey,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    // DoD#8: surface messages set by non-UI layers (signed-out like/history).
    ref.listen<String?>(toastProvider, (previous, next) {
      if (next == null) return;
      scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next)));
      ref.read(toastProvider.notifier).state = null;
    });

    final auth = ref.watch(authProvider);

    if (!auth.initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF000000),
        body: SizedBox.shrink(),
      );
    }

    if (auth.user == null) {
      return const LoginScreen();
    }

    return const MainScreen();
  }
}