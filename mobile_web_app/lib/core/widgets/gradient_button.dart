import 'package:flutter/material.dart';

/// A premium gradient button with coffee→amber gradient fill.
///
/// Drop-in replacement for [FilledButton] on primary CTAs.
class GradientButton extends StatefulWidget {
  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.width = double.infinity,
    this.height = 54.0,
    this.borderRadius = 32.0,
    this.gradient,
    this.isLoading = false,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final double width;
  final double height;
  final double borderRadius;
  final Gradient? gradient;
  final bool isLoading;

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    final gradient = widget.gradient ??
        LinearGradient(
          colors: isDisabled
              ? [
                  cs.onSurface.withValues(alpha: 0.12),
                  cs.onSurface.withValues(alpha: 0.12),
                ]
              : [
                  const Color(0xFF2C2420),
                  const Color(0xFF493C34),
                  const Color(0xFF564942),
                ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        );

    return GestureDetector(
      onTapDown: isDisabled ? null : (_) => _controller.forward(),
      onTapUp: isDisabled
          ? null
          : (_) {
              _controller.reverse();
              widget.onPressed?.call();
            },
      onTapCancel: isDisabled ? null : () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: isDisabled
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF2C2420).withValues(alpha: 0.40),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.3,
                    ),
                    child: widget.child,
                  ),
          ),
        ),
      ),
    );
  }
}
