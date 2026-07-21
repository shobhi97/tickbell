import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/avatar_widget.dart';
import 'bell_tab.dart';
import 'chats_tab.dart';
import 'contacts_tab.dart';

/// Toggle between light/dark — a lightweight in-memory equivalent of the
/// web app's `ThemeProvider` (persisted via SharedPreferences in main.dart's
/// MaterialApp wiring, kept here simple since Flutter's ThemeMode is app-
/// level state).
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final isAdminAsync = ref.watch(isAdminProvider);
    final mode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: TickBellColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.notifications, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('TickBell', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text('When every second matters', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => ref.read(themeModeProvider.notifier).state =
                mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
            tooltip: 'Switch theme',
          ),
          if (isAdminAsync.value == true)
            IconButton(
              icon: const Icon(Icons.shield_moon_outlined),
              tooltip: 'Bell abuse blocks',
              onPressed: () => context.push('/admin/blocks'),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: GestureDetector(
              onTap: () => context.push('/profile'),
              child: AvatarWidget(
                url: profileAsync.value?.avatarUrl,
                initialsSource: profileAsync.value?.displayName ?? '?',
                size: 36,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, icon: Icon(Icons.notifications_outlined), label: Text('Bell')),
                    ButtonSegment(value: 1, icon: Icon(Icons.groups_outlined), label: Text('Groups')),
                    ButtonSegment(value: 2, icon: Icon(Icons.forum_outlined), label: Text('Contacts')),
                  ],
                  selected: {_tabIndex},
                  onSelectionChanged: (s) => setState(() => _tabIndex = s.first),
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _tabIndex,
                children: const [
                  BellTab(),
                  ChatsTab(),
                  ContactsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
