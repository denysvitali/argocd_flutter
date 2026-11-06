/// Clock used to evaluate "now" inside [formatRelativeTime] and other
/// time-relative helpers. Tests override this so golden snapshots that
/// render relative times stay deterministic regardless of wall-clock drift.
DateTime Function() appClock = () => DateTime.now().toUtc();

/// Formats a UTC ISO-8601 timestamp as a human-readable relative time string.
String formatRelativeTime(String timestamp) {
  final parsed = DateTime.tryParse(timestamp);
  if (parsed == null) {
    return timestamp;
  }

  final now = appClock();
  final diff = now.difference(parsed);

  if (diff.isNegative) {
    return timestamp;
  }

  if (diff.inSeconds < 60) {
    return 'just now';
  }
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays < 30) {
    final d = diff.inDays;
    return '$d ${d == 1 ? 'day' : 'days'} ago';
  }
  if (diff.inDays < 365) {
    final months = diff.inDays ~/ 30;
    return '$months ${months == 1 ? 'month' : 'months'} ago';
  }

  final years = diff.inDays ~/ 365;
  return '$years ${years == 1 ? 'year' : 'years'} ago';
}

/// Formats an ISO-8601 timestamp as `<relative> · YYYY-MM-DD HH:mm UTC`.
/// Falls back to the raw input when it cannot be parsed.
String formatTimestampWithRelative(String timestamp) {
  final parsed = DateTime.tryParse(timestamp);
  if (parsed == null) {
    return timestamp;
  }
  final utc = parsed.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  final absolute =
      '${utc.year}-${two(utc.month)}-${two(utc.day)} '
      '${two(utc.hour)}:${two(utc.minute)} UTC';
  final relative = formatRelativeTime(timestamp);
  return relative == timestamp ? absolute : '$relative · $absolute';
}
