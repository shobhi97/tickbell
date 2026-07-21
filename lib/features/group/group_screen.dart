import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/group.dart';
import '../../data/supabase/supabase_client_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/services/ring_action.dart';
import '../../shared/widgets/avatar_widget.dart';
import 'providers/group_providers.dart';

class GroupScreen extends ConsumerStatefulWidget {
  const GroupScreen({super.key, required this.groupId});
  final String groupId;

  @override
  ConsumerState<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends ConsumerState<GroupScreen> {
  Future<void> _editGroup(Group group) async {
    final nameCtrl = TextEditingController(text: group.name);
    final descCtrl = TextEditingController(text: group.description ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit group'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(groupRepositoryProvider).updateGroup(
          groupId: group.id,
          name: nameCtrl.text,
          description: descCtrl.text,
        );
    ref.invalidate(groupDetailProvider(group.id));
  }

  Future<void> _addMember() async {
    final contacts = await ref.read(allProfilesProvider.future);
    final members = ref.read(groupMembersProvider(widget.groupId)).value ?? [];
    final memberIds = members.map((m) => m.userId).toSet();
    final candidates = contacts.where((c) => !memberIds.contains(c.id)).toList();
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Everyone is already in this group')));
      return;
    }
    final chosen = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Add member'),
        children: candidates
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, c.id),
                  child: Row(
                    children: [
                      AvatarWidget(url: c.avatarUrl, initialsSource: c.displayName, size: 28),
                      const SizedBox(width: 10),
                      Text(c.displayName),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
    if (chosen == null) return;
    await ref.read(groupRepositoryProvider).addMember(widget.groupId, chosen);
    ref.invalidate(groupMembersProvider(widget.groupId));
  }

  Future<void> _renameNickname(GroupMember member) async {
    final ctrl = TextEditingController(text: member.nickname ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Nickname for ${member.displayName ?? 'member'}'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Leave blank to clear')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    await ref.read(groupRepositoryProvider).setNickname(member.memberRowId, result);
    ref.invalidate(groupMembersProvider(widget.groupId));
  }

  Future<void> _removeMember(GroupMember member) async {
    final ok = await _confirm('Remove ${member.effectiveName} from this group?');
    if (!ok) return;
    await ref.read(groupRepositoryProvider).removeMember(member.memberRowId);
    ref.invalidate(groupMembersProvider(widget.groupId));
  }

  Future<void> _leaveGroup(String userId) async {
    final ok = await _confirm('Leave this group? You can be re-invited later.');
    if (!ok) return;
    await ref.read(groupRepositoryProvider).leaveGroup(groupId: widget.groupId, userId: userId);
    if (mounted) context.go('/home');
  }

  Future<void> _deleteGroup() async {
    final ok = await _confirm('Delete this group for everyone? This cannot be undone.');
    if (!ok) return;
    await ref.read(groupRepositoryProvider).deleteGroup(widget.groupId);
    if (mounted) context.go('/home');
  }

  Future<bool> _confirm(String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: TickBellColors.destructive),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final myMembership = membersAsync.value?.where((m) => m.userId == userId).firstOrNull;
    final iAmAdmin = myMembership?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(groupAsync.value?.name ?? 'Group'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            color: TickBellColors.accent,
            tooltip: 'Ring group',
            onPressed: () => ringTarget(context, ref, groupId: widget.groupId, targetLabel: groupAsync.value?.name ?? 'group'),
          ),
          if (iAmAdmin)
            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () {
              final g = groupAsync.value;
              if (g != null) _editGroup(g);
            }),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'chat') context.push('/chat/group:${widget.groupId}');
              if (v == 'leave' && userId != null) _leaveGroup(userId);
              if (v == 'delete') _deleteGroup();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'chat', child: Text('Open chat')),
              const PopupMenuItem(value: 'leave', child: Text('Leave group')),
              if (iAmAdmin) const PopupMenuItem(value: 'delete', child: Text('Delete group')),
            ],
          ),
        ],
      ),
      body: groupAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load group: $e')),
        data: (group) {
          if (group == null) return const Center(child: Text('Group not found'));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GroupAvatar(name: group.name, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(group.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          if (group.description != null)
                            Text(group.description!, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Text('MEMBERS', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
                    const Spacer(),
                    if (iAmAdmin)
                      TextButton.icon(onPressed: _addMember, icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Add')),
                  ],
                ),
              ),
              Expanded(
                child: membersAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Failed to load members: $e')),
                  data: (members) => ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, i) {
                      final m = members[i];
                      return ListTile(
                        leading: AvatarWidget(url: m.avatarUrl, initialsSource: m.effectiveName, size: 42),
                        title: Row(
                          children: [
                            Flexible(child: Text(m.effectiveName, overflow: TextOverflow.ellipsis)),
                            if (m.isAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text('Admin', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onPrimaryContainer)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: m.statusMessage != null ? Text(m.statusMessage!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                        trailing: iAmAdmin && m.userId != userId
                            ? PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'nickname') _renameNickname(m);
                                  if (v == 'remove') _removeMember(m);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'nickname', child: Text('Set nickname')),
                                  PopupMenuItem(value: 'remove', child: Text('Remove from group')),
                                ],
                              )
                            : null,
                        onTap: m.userId == userId ? null : () => context.push('/chat/dm:${m.userId}'),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

extension _FirstOrNullX<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
