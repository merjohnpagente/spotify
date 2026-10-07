import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/playlist.dart';
import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/providers.dart';

final trendingSongsProvider = FutureProvider.autoDispose<List<Song>>((ref) {
  return ref.watch(musicServiceProvider).trending(limit: 30);
});

final newReleasesProvider = FutureProvider.autoDispose<List<Song>>((ref) {
  return ref.watch(musicServiceProvider).byGenre('pop', limit: 12);
});

final searchResultsProvider =
    FutureProvider.autoDispose.family<List<Song>, String>((ref, query) {
  if (query.trim().isEmpty) return Future.value(const []);
  return ref
      .watch(musicServiceProvider)
      .search(query.trim(), limit: 30);
});

final genreSongsProvider =
    FutureProvider.autoDispose.family<List<Song>, String>((ref, genre) {
  return ref.watch(musicServiceProvider).byGenre(genre, limit: 30);
});

final recommendationsProvider =
    FutureProvider.autoDispose.family<List<Song>, String>((ref, videoId) {
  return ref.watch(musicServiceProvider).recommendations(videoId, limit: 10);
});

final likedSongsProvider = FutureProvider.autoDispose<List<Song>>((ref) {
  return ref.watch(musicServiceProvider).likedSongs(limit: 100);
});

final myPlaylistsProvider = FutureProvider.autoDispose<List<Playlist>>((ref) {
  return ref.watch(playlistServiceProvider).myPlaylists(limit: 50);
});

final playlistDetailProvider =
    FutureProvider.autoDispose.family<Playlist, String>((ref, id) {
  return ref.watch(playlistServiceProvider).getById(id);
});

final listeningHistoryProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final entries = await ref.watch(musicServiceProvider).history(limit: 50);
  return entries.map(Song.fromJson).toList();
});

final userStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(musicServiceProvider).stats();
});

/// Podcasts: real results from YouTube search — no backend change needed.
/// Merges a few podcast-flavoured queries and dedupes by videoId.
final podcastsProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final music = ref.watch(musicServiceProvider);
  const queries = ['podcasts', 'talk show', 'podcast pinoy'];
  // Parallel — 3x faster than awaiting one-by-one.
  final buckets = await Future.wait(
    queries.map((q) => music.search(q, limit: 15).catchError((_) => <Song>[])),
  );
  final seen = <String>{};
  final merged = <Song>[];
  for (final results in buckets) {
    for (final s in results) {
      if (seen.add(s.videoId)) merged.add(s);
    }
  }
  return merged;
});

/// Swallows per-source failures into an empty list so one failing source
/// never kills a parallel mix.
Future<List<Song>> _safeSongs(Future<List<Song>> f) async {
  try {
    return await f;
  } catch (_) {
    return const [];
  }
}

/// Smart Mix ("AI DJ" v1): builds a personal mix from liked + history +
/// trending, then fills with recommendations. All client-side.
final djMixProvider = FutureProvider.autoDispose<List<Song>>((ref) async {
  final music = ref.watch(musicServiceProvider);
  final seen = <String>{};
  final mix = <Song>[];

  void addAll(List<Song> songs) {
    for (final s in songs) {
      if (seen.add(s.videoId)) mix.add(s);
    }
  }

  // Parallel seeds — one slow source never blocks the others.
  final seeds = await Future.wait([
    _safeSongs(music.likedSongs(limit: 30)),
    _safeSongs(music.history(limit: 30).then(
      (entries) => entries.map(Song.fromJson).toList(),
    )),
    _safeSongs(music.trending(limit: 20)),
  ]);
  for (final bucket in seeds) {
    addAll(bucket);
  }

  mix.shuffle();
  // Fill with recommendations seeded from the first few tracks (parallel,
  // capped at 3 seeds to bound backend load).
  final seedIds = mix.take(3).map((s) => s.videoId).toList();
  if (mix.length < 25 && seedIds.isNotEmpty) {
    final recBuckets = await Future.wait(
      seedIds.map((id) => _safeSongs(music.recommendations(id, limit: 6))),
    );
    for (final bucket in recBuckets) {
      addAll(bucket);
    }
  }
  return mix.take(25).toList();
});
