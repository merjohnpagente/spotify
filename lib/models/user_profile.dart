class UserProfile {
  final String id;
  final String email;
  final String username;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String bio;
  final Map<String, dynamic> preferences;
  final Map<String, dynamic> stats;
  final DateTime? createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    required this.bio,
    required this.preferences,
    required this.stats,
    this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? (json['_id'] as String? ?? ''),
      email: json['email'] as String? ?? '',
      username: json['username'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String? ?? '',
      preferences: json['preferences'] as Map<String, dynamic>? ?? const {},
      stats: json['stats'] as Map<String, dynamic>? ?? const {},
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  String get displayName {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? username : full;
  }

  int get totalListeningSeconds =>
      (stats['totalListeningTime'] as num?)?.toInt() ?? 0;

  int get totalSongsPlayed => (stats['totalSongsPlayed'] as num?)?.toInt() ?? 0;

  int get likedSongsCount => (stats['likedSongsCount'] as num?)?.toInt() ?? 0;
}