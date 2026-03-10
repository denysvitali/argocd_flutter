import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

String formatTimeAgo(DateTime timestamp) {
  final difference = DateTime.now().difference(timestamp);

  if (difference.inSeconds < 60) {
    return 'just now';
  } else if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return '$minutes min${minutes == 1 ? '' : 's'} ago';
  } else if (difference.inHours < 24) {
    final hours = difference.inHours;
    return '$hours hour${hours == 1 ? '' : 's'} ago';
  } else {
    final days = difference.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }
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
        'Updated ${formatTimeAgo(timestamp!)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.greyLight,
        ),
      ),
    );
  }
}
