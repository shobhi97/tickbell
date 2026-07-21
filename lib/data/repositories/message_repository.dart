import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';
import '../models/profile.dart';

/// A DM conversation summary — the most recent message with a given contact,
/// used to render the "Groups" tab's direct-message list (`ChatsTab`'s `dms`
/// query in the React app).
class DmSummary {
  final String otherUserId;
  final ChatMessage lastMessage;
  final Profile? other;
  const DmSummary({required this.otherUserId, required this.lastMessage, this.other});
}

class MessageRepository {
  MessageRepository(this._client);
  final SupabaseClient _client;

  /// Chat header info for either `group:<id>` or `dm:<id>` targets.
  Future<({String title, String? subtitle, String? avatar, bool isGroup})> fetchHeader({
    required bool isGroup,
    required String targetId,
  }) async {
    if (isGroup) {
      final row = await _client.from('groups').select().eq('id', targetId).maybeSingle();
      return (
        title: (row?['name'] as String?) ?? 'Group',
        subtitle: row?['description'] as String?,
        avatar: row?['avatar_url'] as String?,
        isGroup: true,
      );
    }
    final row = await _client
        .from('profiles')
        .select('display_name, avatar_url, status_message')
        .eq('id', targetId)
        .maybeSingle();
    return (
      title: (row?['display_name'] as String?) ?? 'User',
      subtitle: row?['status_message'] as String?,
      avatar: row?['avatar_url'] as String?,
      isGroup: false,
    );
  }

  Future<List<ChatMessage>> fetchMessages({
    required bool isGroup,
    required String targetId,
    required String currentUserId,
  }) async {
    final query = _client.from('messages').select();
    final filtered = isGroup
        ? query.eq('group_id', targetId)
        : query
            .filter('group_id', 'is', null)
            .or('and(sender_id.eq.$currentUserId,recipient_id.eq.$targetId),'
                'and(sender_id.eq.$targetId,recipient_id.eq.$currentUserId)');
    final rows = await filtered.order('created_at');
    return (rows as List).map((r) => ChatMessage.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Map<String, Profile>> fetchSenderProfiles(Iterable<String> senderIds) async {
    final ids = senderIds.toSet().toList();
    if (ids.isEmpty) return {};
    final rows = await _client
        .from('profiles')
        .select('id, display_name, avatar_url')
        .inFilter('id', ids);
    final map = <String, Profile>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      map[row['id'] as String] = Profile(
        id: row['id'] as String,
        displayName: (row['display_name'] as String?) ?? '',
        avatarUrl: row['avatar_url'] as String?,
        createdAt: DateTime.now(),
      );
    }
    return map;
  }

  /// Returns the inserted message id (used to trigger a push dispatch).
  Future<String> sendMessage({
    required String senderId,
    String? groupId,
    String? recipientId,
    required String content,
  }) async {
    final row = await _client
        .from('messages')
        .insert({
          'sender_id': senderId,
          'group_id': groupId,
          'recipient_id': recipientId,
          'content': content,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  /// Last DM per counterpart, for the Groups tab's "chats" list — ports the
  /// `dms` query in `ChatsTab`.
  Future<List<DmSummary>> fetchDmSummaries(String userId) async {
    final rows = await _client
        .from('messages')
        .select('*, sender:profiles!messages_sender_id_profile_fkey(id, display_name, avatar_url), '
            'recipient:profiles!messages_recipient_id_profile_fkey(id, display_name, avatar_url)')
        .not('recipient_id', 'is', null)
        .or('sender_id.eq.$userId,recipient_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(100);

    final seen = <String>{};
    final result = <DmSummary>[];
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final senderId = row['sender_id'] as String;
      final recipientId = row['recipient_id'] as String?;
      final otherId = senderId == userId ? recipientId : senderId;
      if (otherId == null || seen.contains(otherId)) continue;
      seen.add(otherId);
      final otherJson = (senderId == userId ? row['recipient'] : row['sender']) as Map<String, dynamic>?;
      result.add(DmSummary(
        otherUserId: otherId,
        lastMessage: ChatMessage.fromJson(row),
        other: otherJson == null
            ? null
            : Profile(
                id: otherJson['id'] as String? ?? otherId,
                displayName: (otherJson['display_name'] as String?) ?? '',
                avatarUrl: otherJson['avatar_url'] as String?,
                createdAt: DateTime.now(),
              ),
      ));
    }
    return result;
  }

  /// Realtime INSERT subscription for a single chat thread.
  RealtimeChannel watchThread({
    required String channelName,
    required bool isGroup,
    required String targetId,
    required String currentUserId,
    required void Function(ChatMessage) onInsert,
  }) {
    final channel = _client.channel(channelName);
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final m = ChatMessage.fromJson(payload.newRecord);
            final belongs = isGroup
                ? m.groupId == targetId
                : m.groupId == null &&
                    ((m.senderId == currentUserId && m.recipientId == targetId) ||
                        (m.senderId == targetId && m.recipientId == currentUserId));
            if (belongs) onInsert(m);
          },
        )
        .subscribe();
    return channel;
  }
}
