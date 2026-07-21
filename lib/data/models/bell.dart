class Bell {
  final String id;
  final String senderId;
  final String? groupId;
  final String? recipientId;
  final DateTime createdAt;

  // Denormalized fields populated by the bell-history query's embedded select.
  final String? senderDisplayName;
  final String? senderAvatarUrl;
  final String? groupName;

  const Bell({
    required this.id,
    required this.senderId,
    this.groupId,
    this.recipientId,
    required this.createdAt,
    this.senderDisplayName,
    this.senderAvatarUrl,
    this.groupName,
  });

  factory Bell.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    final group = json['groups'] as Map<String, dynamic>?;
    return Bell(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      groupId: json['group_id'] as String?,
      recipientId: json['recipient_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      senderDisplayName: sender?['display_name'] as String?,
      senderAvatarUrl: sender?['avatar_url'] as String?,
      groupName: group?['name'] as String?,
    );
  }
}

enum BellResponseKind { accept, busy, dismiss, reject }

extension BellResponseKindX on BellResponseKind {
  String get value => switch (this) {
        BellResponseKind.accept => 'accept',
        BellResponseKind.busy => 'busy',
        BellResponseKind.dismiss => 'dismiss',
        BellResponseKind.reject => 'reject',
      };
}

/// Result of calling the `send_bell` RPC.
class SendBellResult {
  final bool ok;
  final String? error;
  final bool warning;
  final bool blocked;
  final String? bellId;

  const SendBellResult({
    required this.ok,
    this.error,
    this.warning = false,
    this.blocked = false,
    this.bellId,
  });

  factory SendBellResult.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const SendBellResult(ok: false, error: 'No response from server');
    }
    return SendBellResult(
      ok: json['ok'] == true,
      error: json['error'] as String?,
      warning: json['warning'] == true,
      blocked: json['blocked'] == true,
      bellId: json['bell_id'] as String?,
    );
  }
}

class BellBlock {
  final String id;
  final String userId;
  final DateTime blockedUntil;
  final String reason;
  final DateTime createdAt;
  final BlockedUserSummary? profile;

  const BellBlock({
    required this.id,
    required this.userId,
    required this.blockedUntil,
    required this.reason,
    required this.createdAt,
    this.profile,
  });

  bool get isActive => blockedUntil.isAfter(DateTime.now());

  factory BellBlock.fromJson(Map<String, dynamic> json, {BlockedUserSummary? profile}) => BellBlock(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        blockedUntil: DateTime.parse(json['blocked_until'] as String),
        reason: (json['reason'] as String?) ?? 'abuse',
        createdAt: DateTime.parse(json['created_at'] as String),
        profile: profile,
      );
}

/// Minimal profile projection used on the admin blocks screen
/// (display_name, avatar_url, email only — not the full Profile model).
class BlockedUserSummary {
  final String? displayName;
  final String? avatarUrl;
  final String? email;
  const BlockedUserSummary({this.displayName, this.avatarUrl, this.email});

  factory BlockedUserSummary.fromJson(Map<String, dynamic> json) => BlockedUserSummary(
        displayName: json['display_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        email: json['email'] as String?,
      );
}
