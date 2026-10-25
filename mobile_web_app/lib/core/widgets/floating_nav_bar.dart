import 'dart:ui';
import 'package:flutter/material.dart';

class FloatingNavBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int? badgeCount;

  const FloatingNavBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<FloatingNavBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? cs.surface.withValues(alpha: 0.88)
        : cs.surface.withValues(alpha: 0.90);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: isDark ? 0.15 : 0.2),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: List.generate(items.length, (index) {
                    final item = items[index];
                    final isSelected = index == currentIndex;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(index),
                        behavior: HitTestBehavior.opaque,
                        child: _NavBarItem(
                          item: item,
                          isSelected: isSelected,
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isSelected,
  });

  final FloatingNavBarItem item;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final iconData = isSelected ? (item.activeIcon ?? item.icon) : item.icon;
    final iconColor = isSelected ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    final iconSize = isSelected ? 22.0 : 20.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutQuint,
      margin: EdgeInsets.symmetric(
        vertical: 4,
        horizontal: isSelected ? 0 : 4,
      ),
      padding: EdgeInsets.symmetric(
        vertical: 4,
        horizontal: isSelected ? 12 : 0,
      ),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.85),
                  cs.primary.withValues(alpha: 0.65),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: item.badgeCount != null && item.badgeCount! > 0
                ? Badge(
                    label: Text('${item.badgeCount}',
                        style: const TextStyle(fontSize: 10)),
                    child: Icon(
                      iconData,
                      key: ValueKey<bool>(isSelected),
                      color: isSelected ? Colors.white : iconColor,
                      size: iconSize,
                    ),
                  )
                : Icon(
                    iconData,
                    key: ValueKey<bool>(isSelected),
                    color: isSelected ? Colors.white : iconColor,
                    size: iconSize,
                  ),
          ),
          if (isSelected) ...[
            const SizedBox(height: 2),
            Text(
              item.label,
              style: textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
