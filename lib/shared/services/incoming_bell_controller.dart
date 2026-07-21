import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/bell.dart';
import '../../providers/repository_providers.dart';

class IncomingBellData {
  final String bellId;
  final String senderId;
  final String? groupId;
  final String? recipientId;
  final DateTime createdAt;
  final String senderName;
  final String? senderAvatar;
  final String? groupName;

  const IncomingBellData({
    required this.bellId,
    required this.senderId,
    this.groupId,
    this.recipientId,
    required this.createdAt,
    required this.senderName,
    this.senderAvatar,
    this.groupName,
  });
}

/// Ports `IncomingBellListener` (`incoming-bell.tsx`) — holds the currently
/// displayed incoming-bell popup, if any, and handles Accept/Reject/Busy/
/// Dismiss.
class IncomingBellController extends StateNotifier<IncomingBellData?> {
  IncomingBellController(this._ref) : super(null);
  final Ref _ref;

  void show(IncomingBellData data) => state = data;

  Future<void> respond(BellResponseKind kind, {required String userId}) async {
    final current = state;
    if (current == null) return;
    if (kind != BellResponseKind.dismiss) {
      await _ref.read(bellRepositoryProvider).respondToBell(
            bellId: current.bellId,
            userId: userId,
            response: kind,
          );
    }
    state = null;
  }

  void dismiss() => state = null;
}

final incomingBellControllerProvider =
    StateNotifierProvider<IncomingBellController, IncomingBellData?>((ref) {
  return IncomingBellController(ref);
});
