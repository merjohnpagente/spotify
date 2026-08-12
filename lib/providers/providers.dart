import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:spotify_fy/models/user_profile.dart';
import 'package:spotify_fy/services/api_client.dart';
import 'package:spotify_fy/services/auth_service.dart';
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
  final ApiClient _api;
  final AuthService _authService;
  final TokenStore _tokenStore;

  AuthProvider(this._api, this._authService, this._tokenStore)
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
      final user = await _authService.login(email: email, password: password);
      await _saveSession(user);
      state = state.copyWith(loading: false, initialized: true, user: user);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(loading: false, error: 'Login failed. Please try again.');
      return false;
    }
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
      final user = await _authService.register(
        email: email,
        password: password,
        username: username,
        firstName: firstName,
        lastName: lastName,
      );
      await _saveSession(user);
      state = state.copyWith(loading: false, initialized: true, user: user);
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

  Future<void> _saveSession(UserProfile user) async {
    final access = _api.tokenStore.accessToken;
    final refresh = _api.tokenStore.refreshToken;
    if (access == null || refresh == null) return;
    await _tokenStore.save(accessToken: access, refreshToken: refresh, user: {
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
    });
  }
}

final authProvider = StateNotifierProvider<AuthProvider, AuthState>((ref) {
  final api = ref.watch(apiClientProvider);
  final authService = ref.watch(authServiceProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  return AuthProvider(api, authService, tokenStore);
});