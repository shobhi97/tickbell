import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase/supabase_client_provider.dart';
import '../../providers/app_providers.dart';
import '../../providers/repository_providers.dart';
import '../services/incoming_bell_controller.dart';
import '../services/notification_service_provider.dart';
import '../services/push_availability.dart';
import '../services/sound_service.dart';
import 'incoming_bell_overlay.dart';

/// Wraps every screen behind the auth gate. Ports `_authenticated/route.tsx`:
///   - registers push for the current user (Web Push there → FCM here)
///   - subscribes to `bells` INSERTs → shows the full-screen incoming-bell
///     popup (`IncomingBellListener`)
///   - subscribes to `messages` INSERTs → plays a chime + local notification
///     unless the user is already viewing that thread (`MessageNotifier`)
///   - subscribes to `bell_responses` INSERTs for bells *I* sent → a toast
///     (`BellResponseListener`)
class AuthenticatedShell extends ConsumerStatefulWidget {
  const AuthenticatedShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AuthenticatedShell> createState() => _AuthenticatedShellState();
}

class _AuthenticatedShellState extends ConsumerState<AuthenticatedShell> {
  RealtimeChannel? _bellsChannel;
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _bellResponsesChannel;
  String? _wiredUserId;
  static const _sound = SoundService();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = ref.read(currentUserIdProvider);
    if (userId != null && userId != _wiredUserId) {
      _wiredUserId = userId;
      _teardown();
      _wireUp(userId);
      if (firebasePushAvailable) {
        ref.read(notificationServiceProvider).registerTokenForUser(userId);
      }
    }
  }

  void _wireUp(String userId) {
    final client = ref.read(supabaseClientProvider);
    final bellRepo = ref.read(bellRepositoryProvider);
    final groupRepo = ref.read(groupRepositoryProvider);

    // --- Incoming bells ---------------------------------------------------
    _bellsChannel = bellRepo.watchIncomingBells((bell) async {
      final senderId = bell['sender_id'] as String;
      if (senderId == userId) return; // don't ring self
      final recipientId = bell['recipient_id'] as String?;
      if (recipientId != null && recipientId != userId) return;
      final groupId = bell['group_id'] as String?;

      final senderRow = await client
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', senderId)
          .maybeSingle();
      String? groupName;
      if (groupId != null) {
        final groupRow = await client.from('groups').select('name').eq('id', groupId).maybeSingle();
        groupName = groupRow?['name'] as String?;
      } else if (recipientId == null) {
        return; // neither a DM to me nor a group bell — ignore
      }

      if (!mounted) return;
      ref.read(incomingBellControllerProvider.notifier).show(IncomingBellData(
            bellId: bell['id'] as String,
            senderId: senderId,
            groupId: groupId,
            recipientId: recipientId,
            createdAt: DateTime.parse(bell['created_at'] as String),
            senderName: (senderRow?['display_name'] as String?) ?? 'Someone',
            senderAvatar: senderRow?['avatar_url'] as String?,
            groupName: groupName,
          ));
      _sound.playBellSound();
    });

    // --- Bell responses (for bells I sent) ---------------------------------
    _bellResponsesChannel = bellRepo.watchBellResponses((row) async {
      final responderId = row['user_id'] as String;
      if (responderId == userId) return;
      final bellId = row['bell_id'] as String;
      final bellRow = await client.from('bells').select('id, sender_id').eq('id', bellId).maybeSingle();
      if (bellRow == null || bellRow['sender_id'] != userId) return;

      final responderRow =
          await client.from('profiles').select('display_name').eq('id', responderId).maybeSingle();
      final name = (responderRow?['display_name'] as String?) ?? 'Someone';
      final response = row['response'] as String;
      String? message;
      if (response == 'accept') message = '$name accepted your bell.';
      else if (response == 'reject') message = '$name rejected your bell.';
      else if (response == 'busy') message = '$name is currently busy.';
      if (message == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });

    // --- New messages: chime + suppress for the open thread ---------------
    _messagesChannel = client.channel('messages-inbox')
      ..onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) async {
          final m = payload.newRecord;
          final senderId = m['sender_id'] as String;
          if (senderId == userId) return;
          final groupId = m['group_id'] as String?;
          final recipientId = m['recipient_id'] as String?;

          final isDmToMe = groupId == null && recipientId == userId;
          var isGroupForMe = false;
          if (groupId != null) {
            isGroupForMe = await groupRepo.isMember(groupId: groupId, userId: userId);
          }
          if (!isDmToMe && !isGroupForMe) {
            return;
          }

          final thisChatId = groupId != null ? 'group:$groupId' : 'dm:$senderId';
          final openChatId = ref.read(openChatIdProvider);
          if (openChatId == thisChatId) {
            return; // already viewing this chat
          }

          _sound.playMessageChime();
          // Foreground in-app banner; background/killed delivery is handled
          // by the FCM push path (NotificationService).
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text((m['content'] as String?) ?? 'New message')),
            );
          }
        },
      )
      ..subscribe();
  }

  void _teardown() {
    final client = ref.read(supabaseClientProvider);
    for (final ch in [_bellsChannel, _messagesChannel, _bellResponsesChannel]) {
      if (ch != null) client.removeChannel(ch);
    }
    _bellsChannel = null;
    _messagesChannel = null;
    _bellResponsesChannel = null;
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        const IncomingBellOverlay(),
      ],
    );
  }
}
