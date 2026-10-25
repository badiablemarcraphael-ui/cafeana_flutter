import 'dart:ui';
import 'package:flutter/material.dart';

/// A premium glassmorphism card with:
/// - Animated press scale (tap feedback)
/// - Optional gradient border shimmer
/// - Optional accent color tint
/// - Web hover elevation
class AnimatedGlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final double blur;
  final Color? color;
  final bool showGradientBorder;
  final Color? accentColor;
  final BorderRadius? borderRadius;

  const AnimatedGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.blur = 20.0,
    this.color,
    this.showGradientBorder = false,
    this.accentColor,
    this.borderRadius,
  });

  @override
  State<AnimatedGlassCard> createState() => _AnimatedGlassCardState();
}

class _AnimatedGlassCardState extends State<AnimatedGlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) _controller.reverse();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    if (widget.onTap != null) _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final br = widget.borderRadius ?? BorderRadius.circular(24);

    final cardColor = widget.color ??
        (widget.accentColor != null
            ? widget.accentColor!.withValues(alpha: 0.08)
            : cs.surface.withValues(alpha: 0.72));

    final borderColor = widget.accentColor != null
        ? widget.accentColor!.withValues(alpha: 0.35)
        : cs.outlineVariant.withValues(alpha: _isHovered ? 0.5 : 0.25);

    final shadowOpacity = _isHovered ? 0.12 : 0.06;
    final shadowBlur = _isHovered ? 32.0 : 20.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: br,
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: shadowOpacity),
                  blurRadius: shadowBlur,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: br,
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: widget.blur,
                  sigmaY: widget.blur,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: widget.padding,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: br,
                    border: Border.all(
                      color: borderColor,
                      width: 1.0,
                    ),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
