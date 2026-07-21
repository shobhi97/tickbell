import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/group.dart';

/// Ports `useMyGroups`, `CreateGroupButton`, and `group.$id.tsx` from the
/// React app.
class GroupRepository {
  GroupRepository(this._client);
  final SupabaseClient _client;

  /// Groups the current user belongs to, with `myRole` attached — mirrors
  /// the `group_members` join in `useMyGroups()`.
  Future<List<Group>> fetchMyGroups(String userId) async {
    final rows = await _client
        .from('group_members')
        .select('role, joined_at, groups(*)')
        .eq('user_id', userId);
    final list = rows as List;
    return list
        .where((r) => r['groups'] != null)
        .map((r) => Group.fromJson(
              r['groups'] as Map<String, dynamic>,
              myRole: r['role'] as String?,
            ))
        .toList();
  }

  /// Used by the message notifier to decide whether an incoming group
  /// message targets the current user (mirrors the `group_members` lookup
  /// inside `MessageNotifier` in the React app).
  Future<bool> isMember({required String groupId, required String userId}) async {
    final row = await _client
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();
    return row != null;
  }

  Future<Group?> fetchGroup(String groupId) async {
    final row = await _client.from('groups').select().eq('id', groupId).maybeSingle();
    return row == null ? null : Group.fromJson(row);
  }

  /// `get_group_members` RPC — SECURITY DEFINER, includes nicknames.
  Future<List<GroupMember>> fetchMembers(String groupId) async {
    final rows = await _client.rpc('get_group_members', params: {'_group_id': groupId});
    final list = rows as List;
    return list.map((r) => GroupMember.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Group> createGroup({
    required String createdBy,
    required String name,
    String? description,
    required Set<String> memberIds,
  }) async {
    final groupRow = await _client
        .from('groups')
        .insert({
          'name': name.trim(),
          'description': (description?.trim().isEmpty ?? true) ? null : description!.trim(),
          'created_by': createdBy,
        })
        .select()
        .single();
    final group = Group.fromJson(groupRow);

    final memberRows = [
      {'group_id': group.id, 'user_id': createdBy, 'role': 'admin'},
      ...memberIds.map((id) => {'group_id': group.id, 'user_id': id, 'role': 'member'}),
    ];
    await _client.from('group_members').insert(memberRows);
    return group;
  }

  Future<void> updateGroup({
    required String groupId,
    required String name,
    String? description,
  }) async {
    await _client.from('groups').update({
      'name': name.trim(),
      'description': (description?.trim().isEmpty ?? true) ? null : description!.trim(),
    }).eq('id', groupId);
  }

  Future<void> addMember(String groupId, String userId) async {
    await _client.from('group_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'role': 'member',
    });
  }

  Future<void> removeMember(String memberRowId) async {
    await _client.from('group_members').delete().eq('id', memberRowId);
  }

  Future<void> setNickname(String memberRowId, String? nickname) async {
    await _client
        .from('group_members')
        .update({'nickname': (nickname?.trim().isEmpty ?? true) ? null : nickname!.trim()})
        .eq('id', memberRowId);
  }

  Future<void> leaveGroup({required String groupId, required String userId}) async {
    await _client.from('group_members').delete().eq('group_id', groupId).eq('user_id', userId);
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.from('groups').delete().eq('id', groupId);
  }

  /// Realtime stream of group_members changes for a given group — powers
  /// the group screen's live member list, matching the `postgres_changes`
  /// subscription in `group.$id.tsx`.
  RealtimeChannel watchGroupMembers(String groupId, void Function() onChange) {
    final channel = _client.channel('group-members-$groupId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'group_id',
            value: groupId,
          ),
          callback: (payload) => onChange(),
        )
        .subscribe();
    return channel;
  }
}
