import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/providers.dart';
import 'package:spotify_fy/services/api_client.dart';
import 'package:spotify_fy/services/music_service.dart';
import 'package:spotify_fy/services/token_store.dart';

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
    state = state.copyWith(
      queue: List.of(songs),
      currentIndex: safeIndex,
      isPlaying: true,
      position: Duration.zero,
      duration: Duration.zero,
      clearError: true,
    );
    await _loadAndPlay();
  }

  Future<void> playSong(Song song, {List<Song>? queue}) async {
    final list = queue ?? [song];
    await playQueue(list, index: list.indexWhere((s) => s.videoId == song.videoId).clamp(0, 0));
  }

  Future<void> _loadAndPlay() async {
    final song = state.currentSong;
    if (song == null) return;

    state = state.copyWith(loading: true, isPlaying: true, clearError: true);

    try {
      final quality = _ref
          .read(authProvider)
          .user
          ?.preferences['audioQuality'] as String?;
      final url = await _music.getStreamUrl(song.videoId, quality: quality);
      await _player.stop();
      await _player.setSource(UrlSource(url));
      await _player.setVolume(state.volume);
      await _player.resume();
      state = state.copyWith(
        loading: false,
        isPlaying: true,
        isLiked: _likedIds.contains(song.videoId),
        likedLoaded: true,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        loading: false,
        isPlaying: false,
        error: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        loading: false,
        isPlaying: false,
        error: 'Could not play this song',
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
    if (!_tokenStore.hasSession) return;
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
    if (!_tokenStore.hasSession) return;
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