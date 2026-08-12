class Song {
  final String videoId;
  final String title;
  final String artist;
  final String album;
  final int duration;
  final String thumbnailUrl;
  final int viewCount;
  final String channelId;
  final String genre;
  final String language;
  final bool explicit;
  final bool isAvailable;

  const Song({
    required this.videoId,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.thumbnailUrl,
    required this.viewCount,
    required this.channelId,
    required this.genre,
    required this.language,
    required this.explicit,
    required this.isAvailable,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      videoId: json['videoId'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String? ?? '',
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      channelId: json['channelId'] as String? ?? '',
      genre: json['genre'] as String? ?? '',
      language: json['language'] as String? ?? 'en',
      explicit: json['explicit'] as bool? ?? false,
      isAvailable: json['isAvailable'] as bool? ?? true,
    );
  }

  String get formattedDuration {
    if (duration <= 0) return '0:00';
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedViews {
    if (viewCount <= 0) return '';
    if (viewCount >= 1000000000) return '${(viewCount / 1000000000).toStringAsFixed(1)}B';
    if (viewCount >= 1000000) return '${(viewCount / 1000000).toStringAsFixed(1)}M';
    if (viewCount >= 1000) return '${(viewCount / 1000).toStringAsFixed(1)}K';
    return '$viewCount';
  }
}