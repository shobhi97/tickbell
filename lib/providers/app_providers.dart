import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/group.dart';
import '../data/models/profile.dart';
import '../data/supabase/supabase_client_provider.dart';
import 'repository_providers.dart';

/// `useMyProfile()` equivalent.
final myProfileProvider = FutureProvider.autoDispose<Profile?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(profileRepositoryProvider).fetchMyProfile(userId);
});

/// `useProfiles()` equivalent — every user, ordered by name (used by the
/// create-group member picker and the group-add-member dialog).
final allProfilesProvider = FutureProvider.autoDispose<List<Profile>>((ref) {
  return ref.watch(profileRepositoryProvider).fetchAllProfiles();
});

/// `useIsAdmin()` equivalent.
final isAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  return ref.watch(profileRepositoryProvider).isAdmin(userId);
});

/// `useMyGroups()` equivalent.
final myGroupsProvider = FutureProvider.autoDispose<List<Group>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(groupRepositoryProvider).fetchMyGroups(userId);
});

/// Tracks the chat thread id (`group:<id>` / `dm:<id>`) currently visible on
/// screen, set/cleared by ChatScreen. Used by the message notifier to
/// suppress the chime for the conversation the user is already looking at —
/// mirrors the `location.pathname` check in the React app's `MessageNotifier`.
final openChatIdProvider = StateProvider<String?>((ref) => null);
