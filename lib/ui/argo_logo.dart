import 'dart:math' as math;

import 'package:argocd_flutter/ui/app_colors.dart';
import 'package:flutter/material.dart';

/// ArgoCD-styled logo painted in pure Dart so no SVG dependency is needed.
///
/// Two concentric rings with three orange "node" dots — a stylised reference
/// to the ArgoCD octopus mark and the deployment-graph topology.
class ArgoLogo extends StatelessWidget {
  const ArgoLogo({
    super.key,
    this.size = 48,
    this.ringColor,
    this.dotColor,
    this.coreColor,
    this.haloColor,
  });

  final double size;
  final Color? ringColor;
  final Color? dotColor;
  final Color? coreColor;
  final Color? haloColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _ArgoLogoPainter(
          ringColor: ringColor ?? theme.colorScheme.primary,
          dotColor: dotColor ?? AppColors.orange,
          coreColor: coreColor ?? theme.colorScheme.primary,
          haloColor: haloColor ?? theme.colorScheme.primary.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}

class _ArgoLogoPainter extends CustomPainter {
  const _ArgoLogoPainter({
    required this.ringColor,
    required this.dotColor,
    required this.coreColor,
    required this.haloColor,
  });

  final Color ringColor;
  final Color dotColor;
  final Color coreColor;
  final Color haloColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final outerStroke = (radius * 0.10).clamp(1.5, 3.0);
    final outerRadius = radius * 0.92;
    final innerRingRadius = radius * 0.55;
    final coreRadius = radius * 0.30;
    final dotRadius = radius * 0.13;
    final dotOrbit = radius * 0.78;

    // Soft halo behind everything.
    final haloPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = haloColor;
    canvas.drawCircle(center, radius, haloPaint);

    // Outer ring.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = outerStroke
      ..color = ringColor.withValues(alpha: 0.85);
    canvas.drawCircle(center, outerRadius, ringPaint);

    // Inner filled disc (mid teal).
    final innerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = coreColor.withValues(alpha: 0.32);
    canvas.drawCircle(center, innerRingRadius, innerPaint);

    // Solid core.
    final corePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = coreColor;
    canvas.drawCircle(center, coreRadius, corePaint);

    // Three orange node dots, evenly spaced on the orbit.
    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = dotColor;
    const startAngle = -math.pi / 2;
    for (var i = 0; i < 3; i++) {
      final angle = startAngle + i * (2 * math.pi / 3);
      final dotCenter = Offset(
        center.dx + dotOrbit * math.cos(angle),
        center.dy + dotOrbit * math.sin(angle),
      );
      canvas.drawCircle(dotCenter, dotRadius, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArgoLogoPainter oldDelegate) {
    return ringColor != oldDelegate.ringColor ||
        dotColor != oldDelegate.dotColor ||
        coreColor != oldDelegate.coreColor ||
        haloColor != oldDelegate.haloColor;
  }
}

/// Branded "ArgoCD" wordmark + logo lockup used in the sign-in hero.
class ArgoLockup extends StatelessWidget {
  const ArgoLockup({
    super.key,
    this.logoSize = 56,
    this.title = 'Argo CD',
    this.subtitle,
  });

  final double logoSize;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ArgoLogo(size: logoSize),
        const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
