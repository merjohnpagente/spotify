import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/views/genre_songs_screen.dart';
import 'package:spotify_fy/widgets/genre_card.dart';
import 'package:spotify_fy/widgets/search_result_card.dart';

class SearchTab extends ConsumerStatefulWidget {
  const SearchTab({super.key});

  @override
  ConsumerState<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  String _query = '';

  final List<Map<String, dynamic>> _genres = [
    {'title': 'Pop', 'color': const Color(0xFFE91E63)},
    {'title': 'Hip-Hop', 'color': const Color(0xFF9C27B0)},
    {'title': 'Rock', 'color': const Color(0xFFF44336)},
    {'title': 'Classical', 'color': const Color(0xFF3F51B5)},
    {'title': 'Jazz', 'color': const Color(0xFF009688)},
    {'title': 'Bollywood', 'color': const Color(0xFFFF9800)},
    {'title': 'K-Pop', 'color': const Color(0xFFFFEB3B)},
    {'title': 'Reggae', 'color': const Color(0xFF4CAF50)},
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final text = _searchController.text;
    setState(() {
      _isSearching = text.isNotEmpty;
    });
    if (text.trim().isEmpty) {
      setState(() => _query = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() => _query = text.trim());
      }
    });
  }

  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _playSong(BuildContext context, List<Song> queue, int index) {
    playSongAndOpenPlayer(context, ref, queue[index], queue: queue);
  }

  void _openGenre(String genre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenreSongsScreen(genre: genre),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpotifyColors.primaryBackground,
      appBar: AppBar(
        backgroundColor: SpotifyColors.primaryBackground,
        elevation: 0,
        title: const Text(
          'Search',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: SpotifyColors.secondaryBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(color: SpotifyColors.textPrimary, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Songs, artists, playlists...',
                  hintStyle: const TextStyle(color: SpotifyColors.textSecondary, fontSize: 16),
                  prefixIcon: const Icon(Icons.search, color: SpotifyColors.textSecondary, size: 24),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: SpotifyColors.textSecondary, size: 24),
                          onPressed: () {
                            _searchController.clear();
                            _searchFocusNode.unfocus();
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onTap: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: _isSearching ? _buildSearchResults() : _buildBrowseAll(),
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseAll() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Browse All',
              style: TextStyle(
                color: SpotifyColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
          ),
          itemCount: _genres.length,
          itemBuilder: (context, index) {
            final genre = _genres[index];
            return GenreCard(
              title: genre['title'],
              color: genre['color'],
              onTap: () => _openGenre(genre['title']),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_query.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: const [
          Text(
            'Start typing to search songs',
            style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
          ),
        ],
      );
    }

    final results = ref.watch(searchResultsProvider(_query));

    return results.when(
      data: (songs) => songs.isEmpty
          ? ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: const [
                Text(
                  'No results found',
                  style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                ),
              ],
            )          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                const Text(
                  'Top Results',
                  style: TextStyle(
                    color: SpotifyColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...songs.asMap().entries.map((entry) => SearchResultCard(
                      title: entry.value.title,
                      artist: entry.value.artist,
                      imageUrl: entry.value.thumbnailUrl,
                      onPlay: () => _playSong(context, songs, entry.key),
                      onTap: () => _playSong(context, songs, entry.key),
                    )),
              ],
            ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: SpotifyColors.primaryAccent),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(searchResultsProvider(_query)),
                icon: const Icon(Icons.refresh, color: SpotifyColors.primaryAccent, size: 18),
                label: const Text(
                  'Retry',
                  style: TextStyle(color: SpotifyColors.primaryAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}