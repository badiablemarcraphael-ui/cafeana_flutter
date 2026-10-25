import 'package:flutter/material.dart';

/// A reusable gradient background widget that matches the login page aesthetic.
///
/// Wraps [child] with:
/// - The warm café gradient (dark or light adaptive)
/// - Two decorative blurred circles for visual depth
class AppBackground extends StatelessWidget {
  const AppBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // ── Gradient fill ─────────────────────────────────────────────────────
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? const LinearGradient(
                      colors: [
                        Color(0xFF1F1814),
                        Color(0xFF2C2420),
                        Color(0xFF3B2C1E),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    )
                  : const LinearGradient(
                      colors: [
                        Color(0xFFDCA87C),
                        Color(0xFFC88D5D),
                        Color(0xFFFCFAF8),
                      ],
                      stops: [0.0, 0.4, 1.0],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
            ),
          ),
        ),

        // ── Decorative circles ────────────────────────────────────────────────
        Positioned(
          top: -60,
          right: -40,
          child: _DecorativeCircle(
            size: 200,
            color: cs.primary.withValues(alpha: 0.15),
          ),
        ),
        Positioned(
          top: 80,
          left: -80,
          child: _DecorativeCircle(
            size: 260,
            color: const Color(0xFF2C2420).withValues(alpha: 0.10),
          ),
        ),

        // ── Page content ──────────────────────────────────────────────────────
        child,
      ],
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
