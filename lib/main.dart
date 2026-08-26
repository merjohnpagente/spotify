import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotify_fy/auth/login_screen.dart';
import 'package:spotify_fy/auth/register_screen.dart';
import 'package:spotify_fy/main_screen.dart';
import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/services/token_store.dart';
import 'package:spotify_fy/theme.dart';

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
      title: 'Spotify Clone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
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