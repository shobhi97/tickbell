import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/formatters.dart';
import '../../providers/repository_providers.dart';
import '../../shared/services/ring_action.dart';
import '../../shared/widgets/avatar_widget.dart';
import 'providers/home_providers.dart';

class ContactsTab extends ConsumerStatefulWidget {
  const ContactsTab({super.key});

  @override
  ConsumerState<ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends ConsumerState<ContactsTab> {
  bool _showPhone = false;
  bool _lookingUp = false;
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _addByPhone() async {
    final cleaned = cleanPhoneNumber(_phoneCtrl.text);
    if (cleaned.isEmpty) return;
    if (!isValidPhoneNumber(cleaned)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid phone number')));
      return;
    }
    setState(() => _lookingUp = true);
    try {
      final found = await ref.read(profileRepositoryProvider).findUserByPhone(cleaned);
      if (!mounted) return;
      if (found == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('No TickBell user found with that number')));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Found ${found.displayName}')));
      _phoneCtrl.clear();
      ref.invalidate(contactsSearchResultsProvider);
    } finally {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(contactsSearchResultsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search by name or email', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => ref.read(contactsQueryProvider.notifier).state = v,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showPhone = !_showPhone),
              child: Text(_showPhone ? '− Hide phone lookup' : '+ Find by phone number'),
            ),
          ),
        ),
        if (_showPhone)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(hintText: '+1 555 123 4567'),
                            onSubmitted: (_) => _addByPhone(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _lookingUp ? null : _addByPhone,
                          child: _lookingUp ? const Text('…') : const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Finds any TickBell user who saved this number on their profile.",
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: resultsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load contacts: $e')),
            data: (contacts) {
              if (contacts.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No users match your search.', textAlign: TextAlign.center),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: contacts.length,
                itemBuilder: (context, i) {
                  final c = contacts[i];
                  return ListTile(
                    leading: AvatarWidget(url: c.avatarUrl, initialsSource: c.displayName, size: 44),
                    title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      c.email ?? c.phone ?? c.statusMessage ?? 'Available',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_active_outlined),
                          color: Theme.of(context).colorScheme.secondary,
                          onPressed: () => ringTarget(context, ref, recipientId: c.id, targetLabel: c.displayName),
                        ),
                        const Icon(Icons.chat_bubble_outline),
                      ],
                    ),
                    onTap: () => context.push('/chat/dm:${c.id}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
