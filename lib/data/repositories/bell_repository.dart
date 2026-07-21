import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bell.dart';

class BellRepository {
  BellRepository(this._client);
  final SupabaseClient _client;

  /// `send_bell(_recipient_id, _group_id)` RPC — exactly one of the two must
  /// be non-null. Server enforces the 2-minute / 3-attempt rate limit and
  /// 3-hour block, so the client just surfaces whatever comes back.
  Future<SendBellResult> sendBell({String? recipientId, String? groupId}) async {
    final res = await _client.rpc('send_bell', params: {
      '_recipient_id': recipientId,
      '_group_id': groupId,
    });
    return SendBellResult.fromJson(res as Map<String, dynamic>?);
  }

  Future<List<Bell>> fetchHistory({int limit = 20}) async {
    final rows = await _client
        .from('bells')
        .select('*, groups(name), sender:profiles!bells_sender_id_profile_fkey(display_name, avatar_url)')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => Bell.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> respondToBell({
    required String bellId,
    required String userId,
    required BellResponseKind response,
  }) async {
    await _client.from('bell_responses').upsert(
      {'bell_id': bellId, 'user_id': userId, 'response': response.value},
      onConflict: 'bell_id,user_id',
    );
  }

  /// Admin: list of bell_blocks with the blocked user's profile attached.
  Future<List<BellBlock>> fetchBlocks() async {
    final rows = await _client
        .from('bell_blocks')
        .select('id, user_id, blocked_until, reason, created_at')
        .order('blocked_until', ascending: false);
    final list = rows as List;
    if (list.isEmpty) return [];
    final ids = list.map((r) => r['user_id'] as String).toSet().toList();
    final profileRows = await _client
        .from('profiles')
        .select('id, display_name, avatar_url, email')
        .inFilter('id', ids);
    final byId = {
      for (final p in profileRows as List) p['id'] as String: BlockedUserSummary.fromJson(p as Map<String, dynamic>),
    };
    return list
        .map((r) => BellBlock.fromJson(
              r as Map<String, dynamic>,
              profile: byId[r['user_id']],
            ))
        .toList();
  }

  Future<void> unblock(String blockId) async {
    await _client.from('bell_blocks').delete().eq('id', blockId);
  }

  Future<void> extendBlock(BellBlock block, int hours) async {
    final next = block.blockedUntil.add(Duration(hours: hours));
    await _client.from('bell_blocks').update({'blocked_until': next.toIso8601String()}).eq('id', block.id);
  }

  /// Realtime: fires for every new bell row inserted (server-side RLS still
  /// restricts which rows are readable/visible to this connection).
  RealtimeChannel watchIncomingBells(void Function(Map<String, dynamic> bell) onInsert) {
    final channel = _client.channel('bells-inbox');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bells',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel watchBellResponses(void Function(Map<String, dynamic> row) onInsert) {
    final channel = _client.channel('bell-responses-inbox');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bell_responses',
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
    return channel;
  }

  RealtimeChannel watchBlocks(void Function() onChange) {
    final channel = _client.channel('admin-bell-blocks');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bell_blocks',
          callback: (_) => onChange(),
        )
        .subscribe();
    return channel;
  }
}
