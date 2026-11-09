import 'package:argocd_flutter/core/utils/time_format.dart';
import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:argocd_flutter/ui/design_tokens.dart';
import 'package:flutter/material.dart';

String formatTimeAgo(DateTime timestamp) {
  return formatRelativeTime(timestamp.toUtc().toIso8601String());
}

/// Muted footnote ("Updated 2 min ago") shown beneath list headers.
class LastUpdatedText extends StatelessWidget {
  const LastUpdatedText({super.key, required this.timestamp});

  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    if (timestamp == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'Updated ${formatTimeAgo(timestamp!)}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.secondaryLabel(theme),
          fontFeatures: AppFonts.tabularFigures,
        ),
      ),
    );
  }
}
