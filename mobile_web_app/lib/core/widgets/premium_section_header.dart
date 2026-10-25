import 'package:flutter/material.dart';

/// A premium section header with an accent indicator line, optional icon,
/// and a subtitle. Used consistently across all screens.
class PremiumSectionHeader extends StatelessWidget {
  const PremiumSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.accentColor,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final color = accentColor ?? cs.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Accent line
        Container(
          width: 3,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.3)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),

        // ── Optional icon
        if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
        ],

        // ── Title + subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),

        // ── Trailing
        if (trailing != null) trailing!,
      ],
    );
  }
}
