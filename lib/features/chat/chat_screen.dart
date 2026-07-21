import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/message.dart';
import '../../data/models/profile.dart';
import '../../data/supabase/supabase_client_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/repository_providers.dart';
import '../../shared/services/ring_action.dart';
import '../../shared/widgets/avatar_widget.dart';
import 'providers/chat_providers.dart';

/// `chatId` is `group:<uuid>` or `dm:<uuid>` — matches the route param
/// convention used by `chat.$id.tsx` (`id` is `group-<uuid>`/`dm-<uuid>`
/// there; colon vs dash is just a Flutter route-safe delimiter choice).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.chatId});
  final String chatId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Map<String, Profile> _senderProfiles = {};
  String? _lastSenderProfileKey;

  @override
  void initState() {
    super.initState();
    // Mark this thread as "open" so the app-wide message notifier suppresses
    // its chime while it's on screen (mirrors the location.pathname check in
    // the React app's MessageNotifier).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(openChatIdProvider.notifier).state = widget.chatId;
    });
  }

  @override
  void dispose() {
    if (ref.read(openChatIdProvider) == widget.chatId) {
      ref.read(openChatIdProvider.notifier).state = null;
    }
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadSenderProfilesIfNeeded(List<ChatMessage> messages) async {
    if (!widget.chatId.startsWith('group:')) return;
    final ids = messages.map((m) => m.senderId).toSet();
    final key = ids.join(',');
    if (key == _lastSenderProfileKey) return;
    _lastSenderProfileKey = key;
    final profiles = await ref.read(messageRepositoryProvider).fetchSenderProfiles(ids);
    if (mounted) setState(() => _senderProfiles = profiles);
  }

  Future<void> _send() async {
    final text = _inputCtrl.text;
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    await ref.read(chatMessagesProvider(widget.chatId).notifier).send(text);
    _scrollToBottom();
  }

  Future<void> _ring(String title) async {
    final isGroup = widget.chatId.startsWith('group:');
    final targetId = widget.chatId.split(':').last;
    await ringTarget(
      context,
      ref,
      recipientId: isGroup ? null : targetId,
      groupId: isGroup ? targetId : null,
      targetLabel: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final headerAsync = ref.watch(chatHeaderProvider(widget.chatId));
    final messagesState = ref.watch(chatMessagesProvider(widget.chatId));
    final isGroup = widget.chatId.startsWith('group:');

    ref.listen(chatMessagesProvider(widget.chatId), (prev, next) {
      final list = next.value;
      if (list != null) {
        _loadSenderProfilesIfNeeded(list);
        if (prev?.value != null && next.value!.length > prev!.value!.length) _scrollToBottom();
      }
    });

    final title = headerAsync.value?.title ?? '…';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: isGroup ? () => context.push('/group/${widget.chatId.split(':').last}') : null,
          child: Row(
            children: [
              if (isGroup)
                GroupAvatar(name: title, size: 34)
              else
                AvatarWidget(url: headerAsync.value?.avatar, initialsSource: title, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), overflow: TextOverflow.ellipsis),
                    if (headerAsync.value?.subtitle != null)
                      Text(
                        headerAsync.value!.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            color: TickBellColors.accent,
            tooltip: 'Ring',
            onPressed: () => _ring(title),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Failed to load messages: $e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Say hello 👋'));
                }
                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final mine = m.senderId == userId;
                    final senderName = isGroup ? (_senderProfiles[m.senderId]?.displayName ?? '') : null;
                    return _MessageBubble(message: m, mine: mine, senderName: mine ? null : senderName);
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Message…'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine, this.senderName});
  final ChatMessage message;
  final bool mine;
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (senderName != null && senderName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderName!,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: scheme.primary),
                ),
              ),
            Text(message.content, style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface)),
            const SizedBox(height: 2),
            Text(
              formatClockTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: (mine ? scheme.onPrimary : scheme.onSurface).withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
