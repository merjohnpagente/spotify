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
  final queries = ['podcasts', 'talk show', 'podcast pinoy'];
  final seen = <String>{};
  final merged = <Song>[];
  for (final q in queries) {
    try {
      final results = await music.search(q, limit: 15);
      for (final s in results) {
        if (seen.add(s.videoId)) merged.add(s);
      }
    } catch (_) {
      // One query failing should not kill the whole screen.
    }
  }
  return merged;
});

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

  try {
    addAll(await music.likedSongs(limit: 30));
  } catch (_) {}
  try {
    final history = await music.history(limit: 30);
    addAll(history.map(Song.fromJson).toList());
  } catch (_) {}
  try {
    addAll(await music.trending(limit: 20));
  } catch (_) {}

  mix.shuffle();
  // Fill with recommendations seeded from the first few tracks.
  for (var i = 0; i < mix.length && mix.length < 25 && i < 5; i++) {
    try {
      final recs = await music.recommendations(mix[i].videoId, limit: 6);
      addAll(recs);
    } catch (_) {}
  }
  return mix.take(25).toList();
});
