import 'package:flutter/material.dart';

String formatTimeAgo(DateTime timestamp) {
  final now = DateTime.now();
  final difference = now.difference(timestamp);

  if (difference.inSeconds < 30) {
    return 'just now';
  }
  if (difference.inMinutes < 1) {
    return '${difference.inSeconds} sec ago';
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes min ago';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }

  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class LastUpdatedText extends StatelessWidget {
  const LastUpdatedText({super.key, required this.timestamp});

  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    if (timestamp == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Last updated: ${formatTimeAgo(timestamp!)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}
