import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/bell.dart';
import '../../data/supabase/supabase_client_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/widgets/avatar_widget.dart';

final bellBlocksProvider = FutureProvider.autoDispose<List<BellBlock>>((ref) {
  return ref.watch(bellRepositoryProvider).fetchBlocks();
});

class AdminBlocksScreen extends ConsumerStatefulWidget {
  const AdminBlocksScreen({super.key});

  @override
  ConsumerState<AdminBlocksScreen> createState() => _AdminBlocksScreenState();
}

class _AdminBlocksScreenState extends ConsumerState<AdminBlocksScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _channel = ref.read(bellRepositoryProvider).watchBlocks(() {
        ref.invalidate(bellBlocksProvider);
      });
    });
  }

  @override
  void dispose() {
    if (_channel != null) ref.read(supabaseClientProvider).removeChannel(_channel!);
    super.dispose();
  }

  Future<void> _unblock(BellBlock block) async {
    await ref.read(bellRepositoryProvider).unblock(block.id);
    ref.invalidate(bellBlocksProvider);
  }

  Future<void> _extend(BellBlock block) async {
    await ref.read(bellRepositoryProvider).extendBlock(block, 24);
    ref.invalidate(bellBlocksProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);
    final blocksAsync = ref.watch(bellBlocksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bell abuse blocks')),
      body: isAdminAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (isAdmin) {
          if (!isAdmin) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text("You don't have permission to view this page.", textAlign: TextAlign.center),
              ),
            );
          }
          return blocksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load blocks: $e')),
            data: (blocks) {
              if (blocks.isEmpty) {
                return const Center(child: Text('No active or past bell blocks. 🎉'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: blocks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final b = blocks[i];
                  return Card(
                    child: ListTile(
                      leading: AvatarWidget(
                        url: b.profile?.avatarUrl,
                        initialsSource: b.profile?.displayName ?? '?',
                      ),
                      title: Text(b.profile?.displayName ?? 'Unknown user'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.profile?.email ?? ''),
                          Text('Reason: ${b.reason}'),
                          Text(
                            b.isActive
                                ? 'Blocked until ${b.blockedUntil.toLocal()} (${timeAgo(b.blockedUntil, addSuffix: false)} left)'
                                : 'Expired ${timeAgo(b.blockedUntil)}',
                            style: TextStyle(
                              color: b.isActive ? TickBellColors.destructive : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(onPressed: () => _unblock(b), child: const Text('Unblock')),
                          if (b.isActive)
                            TextButton(onPressed: () => _extend(b), child: const Text('+24h')),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
