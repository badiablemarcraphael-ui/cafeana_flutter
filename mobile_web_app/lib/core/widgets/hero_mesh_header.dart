import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class HeroMeshHeader extends StatelessWidget {
  final String greeting;
  final String name;
  final String? avatarUrl;
  final IconData defaultAvatarIcon;
  final String roleName;
  final VoidCallback? onLogoutTap;

  const HeroMeshHeader({
    super.key,
    required this.greeting,
    required this.name,
    this.avatarUrl,
    required this.defaultAvatarIcon,
    required this.roleName,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppTheme.heroGradientDark : AppTheme.heroGradientLight,
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: SafeArea(
        bottom: false,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Text Area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurface.withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Lora',
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
                      ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: -0.1, end: 0),
                    ],
                  ),
                ),

                // Profile Chip
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Profile Chip (Subtle Pop of Brand Color)
                    Container(
                      margin: const EdgeInsets.only(top: 36),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: cs.secondary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: cs.secondary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            defaultAvatarIcon,
                            color: cs.secondary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            roleName,
                            style: TextStyle(
                              color: cs.secondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
                  ],
                ),
              ],
            ),
            
            // Absolute Top Right Logout Button
            if (onLogoutTap != null)
              Positioned(
                top: -12,
                right: -12,
                child: IconButton(
                  onPressed: onLogoutTap,
                  icon: const Icon(Icons.logout_rounded),
                  color: cs.onSurface.withValues(alpha: 0.7),
                  tooltip: 'Logout',
                ).animate().fadeIn(delay: 300.ms).scale(begin: const Offset(0.9, 0.9)),
              ),
          ],
        ),
      ),
    );
  }
}
