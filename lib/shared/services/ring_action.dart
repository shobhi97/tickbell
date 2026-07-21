import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/repository_providers.dart';
import 'sound_service.dart';

const _sound = SoundService();

/// Rings a user or group and surfaces the result exactly like the React
/// app's `ringGroup`/`ringUser`/`ring` handlers: play the bell sound
/// immediately (optimistic), call `send_bell`, dispatch a push on success,
/// and show a warning/error/success message.
Future<void> ringTarget(
  BuildContext context,
  WidgetRef ref, {
  String? recipientId,
  String? groupId,
  required String targetLabel,
}) async {
  _sound.playBellSound();
  final messenger = ScaffoldMessenger.of(context);
  final result = await ref.read(bellRepositoryProvider).sendBell(
        recipientId: recipientId,
        groupId: groupId,
      );

  if (!result.ok) {
    messenger.showSnackBar(SnackBar(content: Text(result.error ?? 'Could not send bell')));
    return;
  }

  if (result.bellId != null) {
    // Fire-and-forget, matching `dispatchPush(...).catch(console.error)`.
    ref.read(pushRepositoryProvider).dispatch(kind: 'bell', id: result.bellId!).catchError((_) {});
  }

  if (result.warning) {
    messenger.showSnackBar(const SnackBar(
      content: Text('One more Bell attempt within the next 2 minutes will temporarily disable Bell access.'),
    ));
  } else {
    messenger.showSnackBar(SnackBar(content: Text('🔔 Rang $targetLabel')));
  }
}
