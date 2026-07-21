/// `formatDistanceToNow` port (date-fns) — good enough approximation for
/// chat/bell timestamps without pulling in a whole i18n date package.
String timeAgo(DateTime dateTime, {bool addSuffix = true}) {
  final diff = DateTime.now().difference(dateTime);
  final suffix = addSuffix ? ' ago' : '';

  if (diff.inSeconds < 45) return 'less than a minute$suffix';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m minute${m == 1 ? '' : 's'}$suffix';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h hour${h == 1 ? '' : 's'}$suffix';
  }
  if (diff.inDays < 30) {
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'}$suffix';
  }
  if (diff.inDays < 365) {
    final mo = (diff.inDays / 30).floor();
    return '$mo month${mo == 1 ? '' : 's'}$suffix';
  }
  final y = (diff.inDays / 365).floor();
  return '$y year${y == 1 ? '' : 's'}$suffix';
}

String formatClockTime(DateTime dt) {
  final local = dt.toLocal();
  final hour24 = local.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

final _phoneCleanRegex = RegExp(r'[\s()-]');
final _phoneValidRegex = RegExp(r'^\+?[0-9]{7,15}$');

String cleanPhoneNumber(String raw) => raw.trim().replaceAll(_phoneCleanRegex, '');

bool isValidPhoneNumber(String cleaned) => _phoneValidRegex.hasMatch(cleaned);
