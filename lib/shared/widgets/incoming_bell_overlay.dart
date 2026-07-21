import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/bell.dart';
import '../../data/supabase/supabase_client_provider.dart';
import '../services/incoming_bell_controller.dart';
import 'avatar_widget.dart';

/// Port of `IncomingBellListener`'s popup UI in `incoming-bell.tsx`.
class IncomingBellOverlay extends ConsumerWidget {
  const IncomingBellOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incoming = ref.watch(incomingBellControllerProvider);
    if (incoming == null) return const SizedBox.shrink();

    final userId = ref.watch(currentUserIdProvider);

    void respond(BellResponseKind kind) {
      if (userId == null) return;
      unawaited(ref.read(incomingBellControllerProvider.notifier).respond(kind, userId: userId));
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(28),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                decoration: const BoxDecoration(gradient: TickBellColors.bellGradient),
                child: Column(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.notifications_active, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'INCOMING BELL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      incoming.senderName,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (incoming.groupName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'rang · ${incoming.groupName}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    AvatarWidget(url: incoming.senderAvatar, initialsSource: incoming.senderName, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(incoming.senderName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            formatClockTime(incoming.createdAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.4,
                  children: [
                    _ActionButton(
                      icon: Icons.check,
                      label: 'Accept',
                      color: TickBellColors.success,
                      onTap: () => respond(BellResponseKind.accept),
                    ),
                    _ActionButton(
                      icon: Icons.close,
                      label: 'Reject',
                      color: TickBellColors.destructive,
                      onTap: () => respond(BellResponseKind.reject),
                    ),
                    _ActionButton(
                      icon: Icons.do_not_disturb_on_outlined,
                      label: 'Busy',
                      color: Theme.of(context).colorScheme.secondary,
                      onTap: () => respond(BellResponseKind.busy),
                      filled: false,
                    ),
                    _ActionButton(
                      icon: Icons.close,
                      label: 'Dismiss',
                      color: Theme.of(context).colorScheme.outline,
                      onTap: () => respond(BellResponseKind.dismiss),
                      filled: false,
                      outlined: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = true,
    this.outlined = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final child = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
    if (filled) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: child,
      );
    }
    if (outlined) {
      return OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: child,
      );
    }
    return FilledButton.tonal(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: child,
    );
  }
}
