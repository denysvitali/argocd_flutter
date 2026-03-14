import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

String formatTimeAgo(DateTime timestamp) {
  return formatRelativeTime(timestamp.toUtc().toIso8601String());
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
