import 'package:flutter/material.dart';

/// Which edge of the screen the navigation bar the handle controls is on.
enum NavHandleEdge { bottom, left }

/// A small tab-shaped button attached to a navigation bar that lets the user
/// open or close (collapse) the bar.
///
/// The chevron rotates to indicate the action that a tap will perform.
class NavToggleHandle extends StatelessWidget {
  const NavToggleHandle({
    required this.isOpen,
    required this.onTap,
    required this.edge,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    super.key,
  });

  final bool isOpen;
  final VoidCallback onTap;
  final NavHandleEdge edge;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;

  static const Duration animationDuration = Duration(milliseconds: 320);

  @override
  Widget build(BuildContext context) {
    final isBottom = edge == NavHandleEdge.bottom;
    final side = BorderSide(color: borderColor, width: 1.5);

    // The tab is "attached" to the bar, so the edge touching the bar has no
    // border and no rounding.
    final borderRadius = isBottom
        ? const BorderRadius.vertical(top: Radius.circular(14))
        : const BorderRadius.horizontal(right: Radius.circular(14));
    final border = isBottom
        ? Border(top: side, left: side, right: side)
        : Border(top: side, right: side, bottom: side);

    // Bottom bar: arrow points down when open (tap to close), up when closed.
    // Side rail: arrow points left when open (tap to close), right when closed.
    final icon = isBottom
        ? Icons.keyboard_arrow_down_rounded
        : Icons.chevron_left_rounded;

    return Tooltip(
      message: isOpen ? 'Hide navigation' : 'Show navigation',
      child: Semantics(
        button: true,
        label: isOpen ? 'Hide navigation' : 'Show navigation',
        child: Container(
          width: isBottom ? 56 : 22,
          height: isBottom ? 22 : 56,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: borderRadius,
            border: border,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: isBottom ? const Offset(0, -2) : const Offset(2, 0),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: onTap,
              child: Center(
                child: AnimatedRotation(
                  turns: isOpen ? 0 : 0.5,
                  duration: animationDuration,
                  curve: Curves.easeInOutCubic,
                  child: Icon(icon, size: 20, color: iconColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
