import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';

import '../../../core/providers/auth_service.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/widgets/animated_glass_card.dart';
import '../../../core/widgets/premium_section_header.dart';

/// Profile screen for customers.
///
/// Shows the user's display name, email, and a sign-out button.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Future<void> _editField(String title, String initialValue, Future<void> Function(String) onSave) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'New value',
              ),
              validator: (v) => v == null || v.isEmpty ? 'Cannot be empty' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  try {
                    await onSave(controller.text.trim());
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$title updated successfully')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error updating: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateChangesProvider).valueOrNull;
    final uid = user?.uid ?? '';
    final profile = ref.watch(userProfileProvider(uid)).valueOrNull;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayName = profile?.displayName ?? user?.displayName ?? 'Customer';
    final email = user?.email ?? '—';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Gradient hero ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            stretch: true,
            backgroundColor: Colors.transparent,
            title: const Text('Profile',
                style: TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? const LinearGradient(
                          colors: [
                            Color(0xFF2C1A10),
                            Color(0xFF1C1208),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : const LinearGradient(
                          colors: [
                            Color(0xFF4E342E),
                            Color(0xFF6D4C41),
                            Color(0xFF8D6E63),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // ── Avatar ───────────────────────────────────────────────
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glow ring
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        // Avatar circle
                        Container(
                          width: 76,
                          height: 76,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF8D6E63),
                                Color(0xFF6D4C41),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                        .animate()
                        .scale(
                          duration: 500.ms,
                          curve: Curves.easeOutBack,
                        )
                        .fadeIn(duration: 300.ms),

                    const SizedBox(height: 12),

                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 4),

                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ).animate().fadeIn(delay: 250.ms),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
              titlePadding: EdgeInsets.zero,
            ),
          ),

          // ── Body content ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Account info ────────────────────────────────────────────
                PremiumSectionHeader(
                  title: 'Account Info',
                  icon: Icons.manage_accounts_rounded,
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 12),

                AnimatedGlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _InfoTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Display Name',
                        value: displayName,
                        onTap: () {
                          if (user != null) {
                            _editField('Edit Display Name', displayName, (val) async {
                              await user.updateDisplayName(val);
                              await ref.read(firestoreProvider).collection('users').doc(user.uid).update({'displayName': val});
                              await user.reload();
                              setState(() {});
                            });
                          }
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.3),
                      ),
                      _InfoTile(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email,
                        onTap: () {
                          if (user != null) {
                            _editField('Edit Email', email, (val) async {
                              await user.verifyBeforeUpdateEmail(val);
                              await ref.read(firestoreProvider).collection('users').doc(user.uid).update({'email': val});
                              await user.reload();
                              setState(() {});
                            });
                          }
                        },
                      ),
                      if (user?.uid != null) ...[
                        Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.3),
                        ),
                        _InfoTile(
                          icon: Icons.fingerprint_rounded,
                          label: 'User ID',
                          value: user!.uid,
                          isSmall: true,
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.06, end: 0),

                const SizedBox(height: 28),

                // ── Community ────────────────────────────────────────────────
                PremiumSectionHeader(
                  title: 'Community',
                  icon: Icons.people_outline_rounded,
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 12),

                AnimatedGlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        color: cs.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Community Feedback',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'See what others are saying about us.',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    onTap: () =>
                        context.push(AppRoutes.customerCommunityFeedback),
                  ),
                ).animate().fadeIn(delay: 225.ms).slideY(begin: 0.06, end: 0),

                const SizedBox(height: 28),

                // ── Sign out ─────────────────────────────────────────────────
                PremiumSectionHeader(
                  title: 'Account Actions',
                  icon: Icons.settings_rounded,
                ).animate().fadeIn(delay: 250.ms),

                const SizedBox(height: 12),

                AnimatedGlassCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: cs.error,
                        size: 20,
                      ),
                    ),
                    title: const Text(
                      'Sign Out',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'You will be returned to the login screen.',
                      style: TextStyle(
                          fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    onTap: () async {
                      final confirm = await AppDialogs.confirm(
                        context,
                        title: 'Log Out',
                        message: 'Are you sure you want to log out?',
                        isDestructive: true,
                        confirmText: 'Log Out',
                      );
                      if (confirm) {
                        ref.read(authServiceProvider.notifier).signOut();
                      }
                    },
                  ),
                ).animate().fadeIn(delay: 275.ms).slideY(begin: 0.06, end: 0),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info tile ─────────────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.isSmall = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isSmall;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: cs.onPrimaryContainer, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isSmall ? 11 : 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                      fontFamily: isSmall ? 'monospace' : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.edit_outlined, color: cs.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}
