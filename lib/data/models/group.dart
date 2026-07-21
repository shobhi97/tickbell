class Group {
  final String id;
  final String name;
  final String? description;
  final String? avatarUrl;
  final String createdBy;
  final DateTime createdAt;

  /// Populated client-side when loaded via `my_groups` (group_members join).
  final String? myRole;

  const Group({
    required this.id,
    required this.name,
    this.description,
    this.avatarUrl,
    required this.createdBy,
    required this.createdAt,
    this.myRole,
  });

  factory Group.fromJson(Map<String, dynamic> json, {String? myRole}) => Group(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? '',
        description: json['description'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdBy: (json['created_by'] as String?) ?? '',
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ?? DateTime.now(),
        myRole: myRole,
      );

  String get initials {
    final n = name.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    return parts.take(2).map((s) => s.isNotEmpty ? s[0] : '').join().toUpperCase();
  }
}

/// Row returned by the `get_group_members` RPC — joins group_members + profiles.
class GroupMember {
  final String memberRowId;
  final String userId;
  final String role; // 'admin' | 'member'
  final String? nickname;
  final String? displayName;
  final String? avatarUrl;
  final String? statusMessage;

  const GroupMember({
    required this.memberRowId,
    required this.userId,
    required this.role,
    this.nickname,
    this.displayName,
    this.avatarUrl,
    this.statusMessage,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) => GroupMember(
        memberRowId: json['member_row_id'] as String,
        userId: json['user_id'] as String,
        role: (json['role'] as String?) ?? 'member',
        nickname: json['nickname'] as String?,
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        statusMessage: json['status_message'] as String?,
      );

  bool get isAdmin => role == 'admin';

  /// Nickname (per-group) if set, else the profile's display name.
  String get effectiveName {
    final nick = nickname?.trim();
    if (nick != null && nick.isNotEmpty) return nick;
    return displayName ?? 'User';
  }

  String get initials {
    final n = effectiveName.trim();
    if (n.isEmpty) return '?';
    final parts = n.split(RegExp(r'\s+'));
    return parts.take(2).map((s) => s.isNotEmpty ? s[0] : '').join().toUpperCase();
  }
}
