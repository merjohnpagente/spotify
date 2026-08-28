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
