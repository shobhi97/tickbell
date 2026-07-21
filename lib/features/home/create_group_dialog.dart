import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/supabase/supabase_client_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/avatar_widget.dart';

Future<void> showCreateGroupDialog(BuildContext context, WidgetRef ref) {
  return showDialog(
    context: context,
    builder: (_) => const _CreateGroupDialog(),
  );
}

class _CreateGroupDialog extends ConsumerStatefulWidget {
  const _CreateGroupDialog();

  @override
  ConsumerState<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends ConsumerState<_CreateGroupDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<String> _members = {};
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(String userId) async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final group = await ref.read(groupRepositoryProvider).createGroup(
            createdBy: userId,
            name: _nameCtrl.text,
            description: _descCtrl.text,
            memberIds: _members,
          );
      ref.invalidate(myGroupsProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Group "${group.name}" created')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final contactsAsync = ref.watch(allProfilesProvider);

    return AlertDialog(
      title: const Text('New group'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ring a whole team with one tap.'),
              const SizedBox(height: 16),
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Trading Desk')),
              const SizedBox(height: 12),
              TextField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description (optional)')),
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: Text('Members (${_members.length})')),
              const SizedBox(height: 6),
              SizedBox(
                height: 220,
                child: contactsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Failed to load contacts: $e'),
                  data: (contacts) {
                    final others = contacts.where((c) => c.id != userId).toList();
                    if (others.isEmpty) {
                      return const Center(child: Text('No other users yet. You can add members later.'));
                    }
                    return ListView.builder(
                      itemCount: others.length,
                      itemBuilder: (context, i) {
                        final c = others[i];
                        final selected = _members.contains(c.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (_) => setState(() {
                            if (selected) {
                              _members.remove(c.id);
                            } else {
                              _members.add(c.id);
                            }
                          }),
                          secondary: AvatarWidget(url: c.avatarUrl, initialsSource: c.displayName, size: 32),
                          title: Text(c.displayName),
                          controlAffinity: ListTileControlAffinity.trailing,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: (_loading || userId == null || _nameCtrl.text.trim().isEmpty)
              ? null
              : () => _submit(userId),
          child: _loading ? const Text('Creating…') : const Text('Create group'),
        ),
      ],
    );
  }
}
