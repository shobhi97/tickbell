import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/supabase/supabase_client_provider.dart';
import '../../providers/app_providers.dart';
import '../../shared/services/ring_action.dart';
import '../../shared/widgets/avatar_widget.dart';
import 'providers/home_providers.dart';

class BellTab extends ConsumerStatefulWidget {
  const BellTab({super.key});

  @override
  ConsumerState<BellTab> createState() => _BellTabState();
}

class _BellTabState extends ConsumerState<BellTab> with SingleTickerProviderStateMixin {
  bool _ringing = false;

  Future<void> _ring(String? groupId, String label) async {
    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create or join a group first')));
      return;
    }
    setState(() => _ringing = true);
    await ringTarget(context, ref, groupId: groupId, targetLabel: label);
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _ringing = false);
      });
    }
    ref.invalidate(bellHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final groupsAsync = ref.watch(myGroupsProvider);
    final historyAsync = ref.watch(bellHistoryProvider);
    final selected = ref.watch(selectedBellGroupIdProvider);

    return groupsAsync.when(
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, _) => Center(child: Text('Failed to load groups: $e')),
      data: (groups) {
        final activeId = selected ?? (groups.isNotEmpty ? groups.first.id : null);
        final active = groups.where((g) => g.id == activeId).firstOrNull;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            if (groups.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: groups.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final g = groups[i];
                    final isActive = g.id == activeId;
                    return ChoiceChip(
                      label: Text(g.name),
                      selected: isActive,
                      onSelected: (_) => ref.read(selectedBellGroupIdProvider.notifier).state = g.id,
                      selectedColor: Theme.of(context).colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isActive ? Theme.of(context).colorScheme.onPrimary : null,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: (activeId == null || _ringing) ? null : () => _ring(activeId, active?.name ?? ''),
                    child: AnimatedScale(
                      scale: _ringing ? 1.05 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Container(
                        width: 196,
                        height: 196,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: TickBellColors.bellGradient,
                          boxShadow: [
                            BoxShadow(
                              color: TickBellColors.accent.withValues(alpha: 0.35),
                              blurRadius: 42,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications, color: Colors.white, size: 72),
                            SizedBox(height: 8),
                            Text(
                              'RING EVERYONE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      active != null
                          ? 'Rings all ${active.name} members instantly.'
                          : 'Create a group to start ringing.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'RECENT BELLS',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            historyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Failed to load bell history: $e'),
              data: (history) {
                if (history.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('No bells yet. Press the button above 🔔'),
                  );
                }
                return Column(
                  children: history.map((b) {
                    final targetName = b.groupName ?? (b.recipientId == userId ? 'you' : 'a contact');
                    final who = b.senderId == userId ? 'You' : (b.senderDisplayName ?? 'Someone');
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: AvatarWidget(url: b.senderAvatarUrl, initialsSource: b.senderDisplayName ?? '?'),
                        title: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style,
                            children: [
                              TextSpan(text: who, style: const TextStyle(fontWeight: FontWeight.bold)),
                              const TextSpan(text: ' rang '),
                              TextSpan(text: targetName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        subtitle: Text(timeAgo(b.createdAt)),
                        trailing: CircleAvatar(
                          radius: 16,
                          backgroundColor: TickBellColors.accent.withValues(alpha: 0.15),
                          child: const Icon(Icons.notifications, size: 16, color: TickBellColors.accent),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
