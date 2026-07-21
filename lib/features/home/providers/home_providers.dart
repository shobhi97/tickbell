import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/bell.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/supabase/supabase_client_provider.dart';
import '../../../providers/repository_providers.dart';

/// Bell tab: recent bell history (`history` query in `BellTab`).
final bellHistoryProvider = FutureProvider.autoDispose<List<Bell>>((ref) {
  return ref.watch(bellRepositoryProvider).fetchHistory();
});

/// Groups tab: last-DM-per-contact list (`dms` query in `ChatsTab`).
final dmSummariesProvider = FutureProvider.autoDispose<List<DmSummary>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];
  return ref.watch(messageRepositoryProvider).fetchDmSummaries(userId);
});

/// Contacts tab search query text — drives `contactsSearchResultsProvider`.
final contactsQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final contactsSearchResultsProvider = FutureProvider.autoDispose((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final query = ref.watch(contactsQueryProvider);
  if (userId == null) return const [];
  return ref.watch(profileRepositoryProvider).searchContacts(currentUserId: userId, query: query);
});

/// Currently selected group id on the Bell tab (null = auto-pick first).
final selectedBellGroupIdProvider = StateProvider.autoDispose<String?>((ref) => null);
