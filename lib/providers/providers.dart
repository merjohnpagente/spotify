import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotify_fy/models/user_profile.dart';
import 'package:spotify_fy/services/api_client.dart';
import 'package:spotify_fy/services/auth_service.dart';
import 'package:spotify_fy/services/google_auth_service.dart';
import 'package:spotify_fy/services/music_service.dart';
import 'package:spotify_fy/services/playlist_service.dart';
import 'package:spotify_fy/services/token_store.dart';
import 'package:spotify_fy/services/user_service.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  throw UnimplementedError('Overridden in main()');
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: ApiClient.defaultBaseUrl,
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) {
  return GoogleAuthService();
});

final musicServiceProvider = Provider<MusicService>((ref) {
  return MusicService(ref.watch(apiClientProvider));
});

final playlistServiceProvider = Provider<PlaylistService>((ref) {
  return PlaylistService(ref.watch(apiClientProvider));
});

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.watch(apiClientProvider));
});

class AuthState {
  final bool initialized;
  final bool loading;
  final UserProfile? user;
  final String? error;

  const AuthState({
    this.initialized = false,
    this.loading = false,
    this.user,
    this.error,
  });

  AuthState copyWith({
    bool? initialized,
    bool? loading,
    UserProfile? user,
    bool clearUser = false,
    String? error,
  }) {
    return AuthState(
      initialized: initialized ?? this.initialized,
      loading: loading ?? this.loading,
      user: clearUser ? null : (user ?? this.user),
      error: error,
    );
  }
}

class AuthProvider extends StateNotifier<AuthState> {
  final AuthService _authService;
  final GoogleAuthService _googleAuth;
  final TokenStore _tokenStore;

  AuthProvider(this._authService, this._googleAuth, this._tokenStore)
      : super(const AuthState());

  Future<void> init() async {
    if (_tokenStore.hasSession) {
      final cachedUser = _tokenStore.cachedUser;
      state = state.copyWith(
        initialized: true,
        user: cachedUser != null ? UserProfile.fromJson(cachedUser) : null,
      );
      try {
        final fresh = await _authService.me();
        state = state.copyWith(user: fresh);
        await _tokenStore.updateCachedUser({
          'id': fresh.id,
          'email': fresh.email,
          'username': fresh.username,
          'firstName': fresh.firstName,
          'lastName': fresh.lastName,
          'avatarUrl': fresh.avatarUrl,
          'bio': fresh.bio,
          'preferences': fresh.preferences,
          'stats': fresh.stats,
          'createdAt': fresh.createdAt?.toIso8601String(),
        });
      } catch (_) {
        // Token invalid/expired without successful refresh; stay signed out
        await _tokenStore.clear();
        state = state.copyWith(clearUser: true);
      }
    } else {
      state = state.copyWith(initialized: true);
    }
  }

  Future<bool> login({required String email, required String password}) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final session = await _authService.login(email: email, password: password);
      await _saveSession(session);
      state = state.copyWith(loading: false, initialized: true, user: session.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Login failed. Please try again.');
      return false;
    }
  }

  /// Google/Gmail sign-in: Firebase on the device, token exchange with our API.
  /// Returns false without setting [AuthState.error] when the user cancels.
  Future<bool> signInWithGoogle() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final idToken = await _googleAuth.getIdToken();
      if (idToken == null) {
        // User closed the Google dialog - not an error.
        state = state.copyWith(loading: false);
        return false;
      }
      final session = await _authService.googleLogin(idToken);
      await _saveSession(session);
      state = state.copyWith(loading: false, initialized: true, user: session.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } on PlatformException catch (e) {
      final message = _googleErrorMessage(e);
      if (message == null) {
        // User cancelled - not an error.
        state = state.copyWith(loading: false);
        return false;
      }
      state = state.copyWith(loading: false, error: message);
      return false;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.message ?? 'Google sign-in failed. Please try again.',
      );
      return false;
    } on GoogleSignInUnavailableException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(
        loading: false,
        error: 'Google sign-in failed. Check your internet connection and try again.',
      );
      return false;
    }
  }

  /// Maps Google Play Services errors to human-readable messages.
  /// Returns null when the failure is a plain user cancellation.
  String? _googleErrorMessage(PlatformException e) {
    final code = e.code;
    final message = e.message ?? '';
    final details = e.details?.toString() ?? '';

    if (code == 'sign_in_cancelled' ||
        code == 'sign_in_failed_canceled' ||
        message.contains('12500') ||
        message.toLowerCase().contains('canceled') ||
        message.toLowerCase().contains('cancelled')) {
      return null;
    }
    if (details == '10' || message.contains(': 10:') || message.toUpperCase().contains('DEVELOPER_ERROR')) {
      return 'Google sign-in is not configured for this app yet. '
          'Register this PC\'s debug SHA-1 fingerprint in the Firebase console '
          '(Project settings > Your apps > Add fingerprint), re-download '
          'google-services.json into android/app/, and rebuild.';
    }
    if (details == '7' || message.contains(': 7:') || code == 'network_error') {
      return 'Cannot reach Google Play Services. Check your internet connection.';
    }
    if (details == '12501' || message.contains(': 12501')) {
      return null; // sign-in cancelled by user
    }
    if (details == '17' || message.contains(': 17:')) {
      return 'Google Play Services is out of date or unavailable on this device.';
    }
    return 'Google sign-in failed ($code). Please try again.';
  }

  Future<bool> register({
    required String email,
    required String password,
    required String username,
    required String firstName,
    required String lastName,
  }) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final session = await _authService.register(
        email: email,
        password: password,
        username: username,
        firstName: firstName,
        lastName: lastName,
      );
      await _saveSession(session);
      state = state.copyWith(loading: false, initialized: true, user: session.user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Registration failed. Please try again.');
      return false;
    }
  }

  Future<void> logout() async {
    final refreshToken = _tokenStore.refreshToken;
    if (refreshToken != null) {
      unawaited(_authService.logout(refreshToken));
    }
    // Also end any Google/Firebase session so the next sign-in shows
    // the account picker instead of silently reusing the old account.
    unawaited(_googleAuth.signOut());
    await _tokenStore.clear();
    state = state.copyWith(clearUser: true, error: null);
  }

  Future<bool> updateProfile(Map<String, dynamic> updates) async {
    state = state.copyWith(loading: true, error: null);
    try {
      final updated = await _authService.updateProfile(updates);
      await _tokenStore.updateCachedUser({
        'id': updated.id,
        'email': updated.email,
        'username': updated.username,
        'firstName': updated.firstName,
        'lastName': updated.lastName,
        'avatarUrl': updated.avatarUrl,
        'bio': updated.bio,
        'preferences': updated.preferences,
        'stats': updated.stats,
        'createdAt': updated.createdAt?.toIso8601String(),
      });
      state = state.copyWith(loading: false, user: updated);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Update failed. Please try again.');
      return false;
    }
  }

  Future<void> _saveSession(AuthSession session) async {
    final user = session.user;
    await _tokenStore.save(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      user: {
        'id': user.id,
        'email': user.email,
        'username': user.username,
        'firstName': user.firstName,
        'lastName': user.lastName,
        'avatarUrl': user.avatarUrl,
        'bio': user.bio,
        'preferences': user.preferences,
        'stats': user.stats,
        'createdAt': user.createdAt?.toIso8601String(),
      },
    );
  }
}

final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  final googleAuth = ref.watch(googleAuthServiceProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  return AuthProvider(authService, googleAuth, tokenStore);
});