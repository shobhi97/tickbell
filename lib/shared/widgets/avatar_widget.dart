import 'package:flutter/material.dart';

String _initialsOf(String? name) {
  final n = name?.trim() ?? '';
  if (n.isEmpty) return '?';
  final parts = n.split(RegExp(r'\s+'));
  return parts.take(2).map((s) => s.isNotEmpty ? s[0] : '').join().toUpperCase();
}

/// Port of the `Avatar`/`AvatarFallback` shadcn component used throughout
/// the web app — network image with initials fallback.
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    this.url,
    required this.initialsSource,
    this.size = 40,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String? url;
  final String initialsSource;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = backgroundColor ?? scheme.primaryContainer;
    final fg = foregroundColor ?? scheme.onPrimaryContainer;

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bg,
      foregroundColor: fg,
      backgroundImage: (url != null && url!.isNotEmpty) ? NetworkImage(url!) : null,
      child: (url == null || url!.isEmpty)
          ? Text(
              _initialsOf(initialsSource),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: size * 0.36),
            )
          : null,
    );
  }
}

/// Rounded-square gradient "group" avatar (initials only), as used for
/// group chats/tiles instead of a circular photo avatar.
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.name, this.size = 44, this.gradient});

  final String name;
  final double size;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient ??
            LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ],
            ),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      alignment: Alignment.center,
      child: Text(
        _initialsOf(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}
