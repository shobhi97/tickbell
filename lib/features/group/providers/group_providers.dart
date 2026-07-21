import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/group.dart';
import '../../../data/supabase/supabase_client_provider.dart';
import '../../../providers/repository_providers.dart';

final groupDetailProvider =
    FutureProvider.autoDispose.family<Group?, String>((ref, groupId) {
  return ref.watch(groupRepositoryProvider).fetchGroup(groupId);
});

/// Members list, kept fresh via a realtime subscription on group_members —
/// ports the `postgres_changes` effect in `group.$id.tsx`.
class GroupMembersController extends StateNotifier<AsyncValue<List<GroupMember>>> {
  GroupMembersController(this._ref, this.groupId) : super(const AsyncValue.loading()) {
    _load();
    _channel = _ref.read(groupRepositoryProvider).watchGroupMembers(groupId, _load);
  }

  final Ref _ref;
  final String groupId;
  late final RealtimeChannel _channel;

  Future<void> _load() async {
    try {
      final members = await _ref.read(groupRepositoryProvider).fetchMembers(groupId);
      state = AsyncValue.data(members);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _ref.read(supabaseClientProvider).removeChannel(_channel);
    super.dispose();
  }
}

final groupMembersProvider = StateNotifierProvider.autoDispose
    .family<GroupMembersController, AsyncValue<List<GroupMember>>, String>((ref, groupId) {
  return GroupMembersController(ref, groupId);
});
