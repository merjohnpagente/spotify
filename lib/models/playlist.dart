import 'song.dart';

class Playlist {
  final String id;
  final String? userId;
  final String title;
  final String description;
  final String? coverImageUrl;
  final List<String> songIds;
  final int totalDuration;
  final bool isPublic;
  final int followerCount;
  final int playCount;
  final DateTime? createdAt;
  final List<Song> songs;

  const Playlist({
    required this.id,
    this.userId,
    required this.title,
    required this.description,
    this.coverImageUrl,
    required this.songIds,
    required this.totalDuration,
    required this.isPublic,
    required this.followerCount,
    required this.playCount,
    this.createdAt,
    this.songs = const [],
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String? ?? (json['_id'] as String? ?? ''),
      userId: json['userId'] as String?,
      title: json['title'] as String? ?? 'Untitled',
      description: json['description'] as String? ?? '',
      coverImageUrl: json['coverImageUrl'] as String?,
      songIds: (json['songIds'] as List<dynamic>? ?? []).cast<String>(),
      totalDuration: (json['totalDuration'] as num?)?.toInt() ?? 0,
      isPublic: json['isPublic'] as bool? ?? true,
      followerCount: (json['followerCount'] as num?)?.toInt() ?? 0,
      playCount: (json['playCount'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      songs: (json['songs'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Song.fromJson)
          .toList(),
    );
  }
}