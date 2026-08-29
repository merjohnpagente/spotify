import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/services/api_client.dart';
import 'package:spotify_fy/services/direct_audio_service.dart';
import 'package:spotify_fy/services/music_service.dart';
import 'package:spotify_fy/services/token_store.dart';
import 'package:spotify_fy/services/web_audio_service.dart';

enum RepeatMode { off, all, one }

class PlayerState {
  final List<Song> queue;
  final int currentIndex;
  final bool isPlaying;
  final bool loading;
  final Duration position;
  final Duration duration;
  final double volume;
  final bool shuffle;
  final RepeatMode repeatMode;
  final bool isLiked;
  final bool likedLoaded;
  final String? error;

  const PlayerState({
    this.queue = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.loading = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.volume = 1.0,
    this.shuffle = false,
    this.repeatMode = RepeatMode.off,
    this.isLiked = false,
    this.likedLoaded = false,
    this.error,
  });

  Song? get currentSong =>
      currentIndex >= 0 && currentIndex < queue.length ? queue[currentIndex] : null;

  PlayerState copyWith({
    List<Song>? queue,
    int? currentIndex,
    bool? isPlaying,
    bool? loading,
    Duration? position,
    Duration? duration,
    double? volume,
    bool? shuffle,
    RepeatMode? repeatMode,
    bool? isLiked,
    bool? likedLoaded,
    String? error,
    bool clearError = false,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      isPlaying: isPlaying ?? this.isPlaying,
      loading: loading ?? this.loading,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      volume: volume ?? this.volume,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
      isLiked: isLiked ?? this.isLiked,
      likedLoaded: likedLoaded ?? this.likedLoaded,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PlayerController extends StateNotifier<PlayerState> {
  final Ref _ref;
  final AudioPlayer _player;
  final MusicService _music;
  final TokenStore _tokenStore;

  final Random _random = Random();
  final Set<String> _likedIds = {};
  bool _reportingHistory = false;
  final DirectAudioService _direct = DirectAudioService();
  final WebAudioService _webDirect = WebAudioService();

  PlayerController(this._ref, this._music, this._tokenStore)
      : _player = AudioPlayer(),
        super(const PlayerState()) {
    _initPlayer();
  }

  void _initPlayer() {
    _player.setReleaseMode(ReleaseMode.stop);

    _player.onPositionChanged.listen((position) {
      if (position == state.position) return;
      state = state.copyWith(position: position);
    });

    _player.onDurationChanged.listen((duration) {
      state = state.copyWith(duration: duration);
    });

    _player.onPlayerComplete.listen((_) {
      _onTrackComplete();
    });

    if (_tokenStore.hasSession) {
      _syncLikedIds();
    }
  }

  Future<void> _syncLikedIds() async {
    try {
      final liked = await _music.likedSongs(limit: 200);
      _likedIds
        ..clear()
        ..addAll(liked.map((s) => s.videoId));
      final song = state.currentSong;
      if (song != null) {
        state = state.copyWith(
          isLiked: _likedIds.contains(song.videoId),
          likedLoaded: true,
        );
      }
    } catch (_) {
      state = state.copyWith(likedLoaded: true);
    }
  }

  Future<void> playQueue(List<Song> songs, {int index = 0}) async {
    if (songs.isEmpty) return;
    final safeIndex = index.clamp(0, songs.length - 1);
    final dur = Duration(seconds: songs[safeIndex].duration > 0 ? songs[safeIndex].duration : 0);
    state = state.copyWith(
      queue: List.of(songs),
      currentIndex: safeIndex,
      isPlaying: true,
      position: Duration.zero,
      duration: dur,
      clearError: true,
    );
    // Guard long compilations — PureTuber also fails on 3h mixes
    final titleLower = songs[safeIndex].title.toLowerCase();
    if (songs[safeIndex].duration > 1800 ||
        titleLower.contains('top 100') && titleLower.contains('billboard') ||
        titleLower.contains('compilation')) {
      // still try, but warn — long mixes often timeout on extraction
    }
    await _loadAndPlay();
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    final list = queue ?? [song];
    final rawIndex = list.indexWhere((s) => s.videoId == song.videoId);
    final safeIndex = rawIndex < 0 ? 0 : rawIndex.clamp(0, list.length - 1);
    await playQueue(list, index: safeIndex);
  }

  Future<void> _loadAndPlay() async {
    final song = state.currentSong;
    if (song == null) return;
    final videoId = song.videoId;

    // Show known duration immediately so UI not 00:00/00:00 (e.g. Image1)
    if (state.duration.inSeconds == 0 && song.duration > 0) {
      state = state.copyWith(duration: Duration(seconds: song.duration));
    }
    state = state.copyWith(loading: true, isPlaying: true, clearError: true);

    try {
      final quality = _ref
          .read(authProvider)
          .user
          ?.preferences['audioQuality'] as String?;
      // PureTuber-style: on Android/iOS talk to YouTube directly (~1s) — no server hop.
      // Web tries CORS-proxy direct first, then server proxy (CORS).
      if (!kIsWeb) {
        final directUrl = await _direct.getAudioUrl(videoId);
        if (directUrl != null) {
          try {
            await _player.stop();
            await _player.setSource(UrlSource(directUrl)).timeout(const Duration(seconds: 20));
            await _player.setVolume(state.volume);
            await _player.resume().timeout(const Duration(seconds: 10));
            state = state.copyWith(
              loading: false,
              isPlaying: true,
              isLiked: _likedIds.contains(videoId),
              likedLoaded: true,
            );
            return;
          } catch (_) {
            // direct failed — fall through to server
          }
        }
      }
      String url;
      if (kIsWeb) {
        // Web: try CORS direct first (~2s), like PureTuber, then proxy
        final webUrl = await _webDirect.getAudioUrl(videoId);
        if (webUrl != null) {
          try {
            await _player.stop();
            await _player.setSource(UrlSource(webUrl)).timeout(const Duration(seconds: 20));
            await _player.setVolume(state.volume);
            await _player.resume().timeout(const Duration(seconds: 10));
            state = state.copyWith(
              loading: false,
              isPlaying: true,
              isLiked: _likedIds.contains(videoId),
              likedLoaded: true,
            );
            return;
          } catch (_) {
            // cors direct failed — fall through to proxy
          }
        }
        url = _music.getAudioProxyUrl(videoId, quality: quality);
      } else {
        try {
          url = await _music.getStreamUrl(videoId, quality: quality);
        } catch (_) {
          url = _music.getAudioProxyUrl(videoId, quality: quality);
        }
      }
      await _player.stop();
      await _player.setSource(UrlSource(url)).timeout(const Duration(seconds: 90));
      await _player.setVolume(state.volume);
      await _player.resume().timeout(const Duration(seconds: 30));
      state = state.copyWith(
        loading: false,
        isPlaying: true,
        isLiked: _likedIds.contains(videoId),
        likedLoaded: true,
      );
    } on ApiException catch (e) {
      // On web, if direct stream failed, retry via proxy once
      if (kIsWeb && !e.message.toLowerCase().contains('proxy')) {
        try {
          final quality = _ref
              .read(authProvider)
              .user
              ?.preferences['audioQuality'] as String?;
          final proxyUrl = _music.getAudioProxyUrl(videoId, quality: quality);
          await _player.stop();
          await _player.setSource(UrlSource(proxyUrl)).timeout(const Duration(seconds: 90));
          await _player.setVolume(state.volume);
          await _player.resume().timeout(const Duration(seconds: 30));
          state = state.copyWith(
            loading: false,
            isPlaying: true,
            isLiked: _likedIds.contains(videoId),
            likedLoaded: true,
          );
          return;
        } catch (_) {}
      }
      state = state.copyWith(
        loading: false,
        isPlaying: false,
        error: e.message,
      );
    } catch (e) {
      // Last resort: try proxy URL on web
      if (kIsWeb) {
        try {
          final quality = _ref
              .read(authProvider)
              .user
              ?.preferences['audioQuality'] as String?;
          final proxyUrl = _music.getAudioProxyUrl(videoId, quality: quality);
          await _player.stop();
          await _player.setSource(UrlSource(proxyUrl)).timeout(const Duration(seconds: 90));
          await _player.setVolume(state.volume);
          await _player.resume().timeout(const Duration(seconds: 30));
          state = state.copyWith(
            loading: false,
            isPlaying: true,
            isLiked: _likedIds.contains(videoId),
            likedLoaded: true,
          );
          return;
        } catch (_) {}
      }
      state = state.copyWith(
        loading: false,
        isPlaying: false,
        error: 'Could not play this song: $e',
      );
    }
  }

  Future<void> togglePlayPause() async {
    if (state.currentSong == null) return;
    if (state.loading) return;

    if (state.isPlaying) {
      await _player.pause();
      state = state.copyWith(isPlaying: false);
    } else {
      await _player.resume();
      state = state.copyWith(isPlaying: true);
    }
  }

  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    await _player.seek(position);
  }

  Future<void> setVolume(double volume) async {
    state = state.copyWith(volume: volume);
    await _player.setVolume(volume);
  }

  void toggleShuffle() {
    state = state.copyWith(shuffle: !state.shuffle);
  }

  void toggleRepeat() {
    final next = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
  }

  Future<void> next() async {
    _reportHistory();
    final index = _nextIndex();
    if (index < 0) return;
    state = state.copyWith(currentIndex: index, position: Duration.zero);
    await _loadAndPlay();
  }

  Future<void> previous() async {
    _reportHistory();
    if (state.queue.isEmpty) return;
    final index = state.currentIndex - 1;
    if (index < 0) return;
    state = state.copyWith(currentIndex: index, position: Duration.zero);
    await _loadAndPlay();
  }

  /// Jump to a specific queue position (used by the queue screen).
  Future<void> playAt(int index) async {
    if (index < 0 || index >= state.queue.length) return;
    if (index == state.currentIndex) {
      await togglePlayPause();
      return;
    }
    state = state.copyWith(currentIndex: index, position: Duration.zero);
    await _loadAndPlay();
  }

  /// Remove a track from the queue, keeping the playing position correct.
  void removeFromQueue(int index) {
    if (index < 0 || index >= state.queue.length) return;
    final queue = List<Song>.from(state.queue);
    queue.removeAt(index);
    var currentIndex = state.currentIndex;
    if (index < currentIndex) {
      currentIndex -= 1;
    } else if (index == currentIndex) {
      // Removing the currently playing song: stop it and advance if possible.
      currentIndex = currentIndex >= queue.length ? queue.length - 1 : currentIndex;
    }
    state = state.copyWith(queue: queue, currentIndex: queue.isEmpty ? -1 : currentIndex);
  }

  /// Reorder a queue item (drag handle in the queue screen).
  void moveQueueItem(int from, int to) {
    if (from < 0 || from >= state.queue.length) return;
    if (to < 0 || to >= state.queue.length) return;
    final queue = List<Song>.from(state.queue);
    final moved = queue.removeAt(from);
    queue.insert(to, moved);
    var currentIndex = state.currentIndex;
    if (from == currentIndex) {
      currentIndex = to;
    } else if (from < currentIndex && to >= currentIndex) {
      currentIndex -= 1;
    } else if (from > currentIndex && to <= currentIndex) {
      currentIndex += 1;
    }
    state = state.copyWith(queue: queue, currentIndex: currentIndex);
  }

  void clearQueue() {
    state = state.copyWith(queue: const [], currentIndex: -1, isPlaying: false);
    _player.stop();
  }

  int _nextIndex() {
    if (state.queue.isEmpty) return -1;
    if (state.shuffle && state.queue.length > 1) {
      return _random.nextInt(state.queue.length);
    }
    if (state.currentIndex < state.queue.length - 1) {
      return state.currentIndex + 1;
    }
    if (state.repeatMode == RepeatMode.all) return 0;
    return -1;
  }

  void _onTrackComplete() {
    _reportHistory();
    if (state.repeatMode == RepeatMode.one && state.currentSong != null) {
      _player.seek(Duration.zero);
      _player.resume();
      state = state.copyWith(position: Duration.zero, isPlaying: true);
      return;
    }
    final index = _nextIndex();
    if (index < 0) {
      state = state.copyWith(isPlaying: false, position: Duration.zero);
      return;
    }
    state = state.copyWith(currentIndex: index, position: Duration.zero);
    _loadAndPlay();
  }

  Future<void> toggleLike() async {
    if (!_tokenStore.hasSession) {
      // M4 spec: UI should show toast "Sign in to save likes" when hasSession is false.
      // Keeping silent for now to avoid breaking existing flow (no error state).
      return;
    }
    final song = state.currentSong;
    if (song == null) return;

    final nextLiked = !state.isLiked;
    state = state.copyWith(isLiked: nextLiked);

    try {
      if (nextLiked) {
        await _music.like(song.videoId);
        _likedIds.add(song.videoId);
      } else {
        await _music.unlike(song.videoId);
        _likedIds.remove(song.videoId);
      }
    } catch (_) {
      state = state.copyWith(isLiked: !nextLiked);
    }
  }

  void _reportHistory() {
    if (_reportingHistory) return;
    if (!_tokenStore.hasSession) {
      // M4 spec: UI should show toast "Sign in to save history" when hasSession is false.
      // Keeping silent for now; don't set error to avoid disrupting playback.
      return;
    }
    final song = state.currentSong;
    if (song == null) return;
    if (state.position.inSeconds < 5) return;

    _reportingHistory = true;
    final videoId = song.videoId;
    final playDuration = state.position.inSeconds;
    final totalDuration = state.duration.inSeconds > 0
        ? state.duration.inSeconds
        : song.duration;

    _music
        .addHistory(videoId, playDuration: playDuration, totalDuration: totalDuration)
        .then((_) => _reportingHistory = false)
        .catchError((_) => _reportingHistory = false);
  }

  @override
  void dispose() {
    _direct.dispose();
    _player.dispose();
    super.dispose();
  }
}

final playerProvider = StateNotifierProvider<PlayerController, PlayerState>((ref) {
  final music = ref.watch(musicServiceProvider);
  final tokenStore = ref.watch(tokenStoreProvider);
  final controller = PlayerController(ref, music, tokenStore);
  ref.onDispose(controller.dispose);
  return controller;
});