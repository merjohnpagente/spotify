import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotify_fy/models/song.dart';
import 'package:spotify_fy/providers/music_providers.dart';
import 'package:spotify_fy/services/api_client.dart';
import 'package:spotify_fy/theme.dart';
import 'package:spotify_fy/utils/player_nav.dart';
import 'package:spotify_fy/views/artist_screen.dart';
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
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _query = text.trim());
      }
    });
  }

  bool _isSearching = false;
  String _searchTab = 'songs';

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
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: false,
      data: (songs) => songs.isEmpty
          ? ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: const [
                Text(
                  'No results found',
                  style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildResultTabs(),
                const SizedBox(height: 8),
                if (_searchTab == 'songs') ...[
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
                ] else
                  _buildArtistsList(songs),
              ],
            ),
      loading: () => const Center(
        child: CircularProgressIndicator(color: SpotifyColors.primaryAccent),
      ),
      error: (e, _) {
        final msgLower = e.toString().toLowerCase();
        final isNetworkError = (e is ApiException && e.statusCode == 0) ||
            msgLower.contains('cannot reach server') ||
            msgLower.contains('waking up');
        return Center(
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
                if (isNetworkError) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Base URL: ${ApiClient.defaultBaseUrl}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SpotifyColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If on physical device, run: flutter run --dart-define=API_BASE_URL=http://<YOUR_PC_IP>:3000',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 12),
                  ),
                ],
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
        );
      },
    );
  }

  Widget _buildResultTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: SpotifyColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              label: 'Songs',
              active: _searchTab == 'songs',
              onTap: () => setState(() => _searchTab = 'songs'),
            ),
          ),
          Expanded(
            child: _TabButton(
              label: 'Artists',
              active: _searchTab == 'artists',
              onTap: () => setState(() => _searchTab = 'artists'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistsList(List<Song> songs) {
    final seen = <String>{};
    final artists = <Song>[];
    for (final s in songs) {
      final key = s.artist.toLowerCase();
      if (key.isNotEmpty && !seen.contains(key)) {
        seen.add(key);
        artists.add(s);
      }
    }
    if (artists.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No artists found',
          style: TextStyle(color: SpotifyColors.textSecondary, fontSize: 14),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Artists',
          style: TextStyle(
            color: SpotifyColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...artists.map((s) => _ArtistListTile(
              name: s.artist,
              imageUrl: s.thumbnailUrl,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ArtistScreen(artist: s.artist)),
              ),
            )),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? SpotifyColors.primaryAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? SpotifyColors.textPrimary : SpotifyColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ArtistListTile extends StatelessWidget {
  final String name;
  final String imageUrl;
  final VoidCallback onTap;

  const _ArtistListTile({
    required this.name,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipOval(
              child: Image.network(
                imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 56,
                  height: 56,
                  color: SpotifyColors.cardBackground,
                  child: const Icon(Icons.person, color: SpotifyColors.textSecondary, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: SpotifyColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Artist',
                    style: TextStyle(
                      color: SpotifyColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: SpotifyColors.textSecondary),
          ],
        ),
      ),
    );
  }
}