class Profile {
  final String id;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String? phone;
  final String? statusMessage;
  final DateTime createdAt;

  const Profile({
    required this.id,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.phone,
    this.statusMessage,
    required this.createdAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'] as String,
        displayName: (json['display_name'] as String?) ?? '',
        email: json['email'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        phone: json['phone'] as String?,
        statusMessage: json['status_message'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return '?';
    final parts = name.split(RegExp(r'\s+'));
    return parts.take(2).map((s) => s.isNotEmpty ? s[0] : '').join().toUpperCase();
  }
}
