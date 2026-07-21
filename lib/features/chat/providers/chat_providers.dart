import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/message.dart';
import '../../../data/supabase/supabase_client_provider.dart';
import '../../../providers/repository_providers.dart';

/// Header info (title/subtitle/avatar) for a `group:<id>` or `dm:<id>` target.
final chatHeaderProvider = FutureProvider.autoDispose
    .family<({String title, String? subtitle, String? avatar, bool isGroup}), String>((ref, chatId) {
  final isGroup = chatId.startsWith('group:');
  final targetId = chatId.split(':').last;
  return ref.watch(messageRepositoryProvider).fetchHeader(isGroup: isGroup, targetId: targetId);
});

/// Full message list + sender-profile lookup for a chat thread, kept live
/// via a realtime channel for the lifetime of the provider.
class ChatMessagesController extends StateNotifier<AsyncValue<List<ChatMessage>>> {
  ChatMessagesController(this._ref, this.chatId) : super(const AsyncValue.loading()) {
    _load();
  }

  final Ref _ref;
  final String chatId;
  RealtimeChannel? _channel;

  bool get isGroup => chatId.startsWith('group:');
  String get targetId => chatId.split(':').last;

  Future<void> _load() async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    try {
      final messages = await _ref.read(messageRepositoryProvider).fetchMessages(
            isGroup: isGroup,
            targetId: targetId,
            currentUserId: userId,
          );
      state = AsyncValue.data(messages);
      _subscribe(userId);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribe(String userId) {
    _channel = _ref.read(messageRepositoryProvider).watchThread(
          channelName: 'chat-$chatId',
          isGroup: isGroup,
          targetId: targetId,
          currentUserId: userId,
          onInsert: (m) {
            final current = state.value ?? [];
            if (current.any((existing) => existing.id == m.id)) return;
            state = AsyncValue.data([...current, m]);
          },
        );
  }

  Future<void> send(String content) async {
    final userId = _ref.read(currentUserIdProvider);
    if (userId == null || content.trim().isEmpty) return;
    final id = await _ref.read(messageRepositoryProvider).sendMessage(
          senderId: userId,
          groupId: isGroup ? targetId : null,
          recipientId: isGroup ? null : targetId,
          content: content.trim(),
        );
    // Fire-and-forget push dispatch, matching `dispatchPush(...).catch(...)`.
    _ref.read(pushRepositoryProvider).dispatch(kind: 'message', id: id).catchError((_) {});
  }

  @override
  void dispose() {
    if (_channel != null) {
      _ref.read(supabaseClientProvider).removeChannel(_channel!);
    }
    super.dispose();
  }
}

final chatMessagesProvider = StateNotifierProvider.autoDispose
    .family<ChatMessagesController, AsyncValue<List<ChatMessage>>, String>((ref, chatId) {
  return ChatMessagesController(ref, chatId);
});
