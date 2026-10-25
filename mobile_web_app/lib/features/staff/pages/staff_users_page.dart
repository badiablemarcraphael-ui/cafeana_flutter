import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/models/user_profile.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/widgets/animated_glass_card.dart';

class StaffUsersPage extends ConsumerStatefulWidget {
  const StaffUsersPage({super.key});

  @override
  ConsumerState<StaffUsersPage> createState() => _StaffUsersPageState();
}

class _StaffUsersPageState extends ConsumerState<StaffUsersPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  UserRole? _roleFilter;
  int _page = 0;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<UserProfile> _applyFilters(List<UserProfile> all) {
    return all.where((user) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final nameMatch =
            (user.displayName ?? '').toLowerCase().contains(q);
        final emailMatch = user.email.toLowerCase().contains(q);
        if (!nameMatch && !emailMatch) return false;
      }
      if (_roleFilter != null && user.role != _roleFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allUsersProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('User Management')),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (allUsers) {
          final filtered = _applyFilters(allUsers);
          final totalPages =
              (filtered.length / _pageSize).ceil().clamp(1, 9999);
          final start = _page * _pageSize;
          final end = (start + _pageSize).clamp(0, filtered.length);
          final pageUsers = filtered.sublist(start, end);

          return Column(
            children: [
              // ── Search & Filter ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    // Search input
                    TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search by name or email…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() {
                                  _searchCtrl.clear();
                                  _query = '';
                                  _page = 0;
                                }),
                              )
                            : null,
                        filled: true,
                        fillColor:
                            cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (v) => setState(() {
                        _query = v.trim();
                        _page = 0;
                      }),
                    ).animate().fadeIn(duration: 300.ms),

                    const SizedBox(height: 10),

                    // Role filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _RoleChip(
                            label: 'All',
                            icon: Icons.people_alt_outlined,
                            selected: _roleFilter == null,
                            color: cs.primary,
                            onTap: () => setState(() {
                              _roleFilter = null;
                              _page = 0;
                            }),
                          ),
                          const SizedBox(width: 8),
                          ...UserRole.values.map((role) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _RoleChip(
                                  label: role.name.toUpperCase(),
                                  icon: _getRoleIcon(role),
                                  selected: _roleFilter == role,
                                  color: _getRoleColor(role, cs),
                                  onTap: () => setState(() {
                                    _roleFilter = role;
                                    _page = 0;
                                  }),
                                ),
                              )),
                        ],
                      ),
                    ).animate().fadeIn(delay: 100.ms),
                  ],
                ),
              ),

              // ── Results count ─────────────────────────────────────────────
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} user${filtered.length == 1 ? '' : 's'} found',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    if (_query.isNotEmpty || _roleFilter != null) ...[
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setState(() {
                          _searchCtrl.clear();
                          _query = '';
                          _roleFilter = null;
                          _page = 0;
                        }),
                        icon: const Icon(Icons.filter_alt_off, size: 14),
                        label: const Text('Clear',
                            style: TextStyle(fontSize: 12)),
                        style: TextButton.styleFrom(
                          foregroundColor: cs.error,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── List ────────────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_search_outlined,
                                size: 56, color: cs.onSurfaceVariant),
                            const SizedBox(height: 12),
                            Text(
                              'No users match your filters.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        itemCount: pageUsers.length,
                        itemBuilder: (context, index) {
                          final user = pageUsers[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AnimatedGlassCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getRoleColor(user.role, cs),
                                  child: Icon(_getRoleIcon(user.role),
                                      color: Colors.white),
                                ),
                                title:
                                    Text(user.displayName ?? user.email),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(user.email,
                                        style:
                                            const TextStyle(fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getRoleColor(user.role, cs)
                                            .withValues(alpha: 0.15),
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        user.role.name.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              _getRoleColor(user.role, cs),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: _RoleDropdown(user: user),
                              ),
                            ).animate().fadeIn(delay: (50 * index).ms).slideX(begin: 0.05, end: 0),
                          );
                        },
                      ).animate().fadeIn(duration: 300.ms),
              ),

              // ── Pagination ───────────────────────────────────────────────
              if (filtered.isNotEmpty)
                _UserPaginationBar(
                  page: _page,
                  totalPages: totalPages,
                  totalItems: filtered.length,
                  pageSize: _pageSize,
                  onPrev: _page > 0 ? () => setState(() => _page--) : null,
                  onNext: _page < totalPages - 1
                      ? () => setState(() => _page++)
                      : null,
                  onPageSelected: (p) => setState(() => _page = p),
                ),
            ],
          );
        },
      ),
    );
  }

  Color _getRoleColor(UserRole role, ColorScheme cs) {
    switch (role) {
      case UserRole.owner:
        return Colors.red[700]!;
      case UserRole.cashier:
        return Colors.blue[700]!;
      case UserRole.kitchen:
        return Colors.orange[700]!;
      case UserRole.customer:
        return Colors.green[700]!;
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return Icons.admin_panel_settings;
      case UserRole.cashier:
        return Icons.point_of_sale;
      case UserRole.kitchen:
        return Icons.kitchen;
      case UserRole.customer:
        return Icons.person;
    }
  }
}

// ── Role filter chip ──────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: selected ? 1.0 : 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: selected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Role dropdown ─────────────────────────────────────────────────────────────

class _RoleDropdown extends ConsumerStatefulWidget {
  const _RoleDropdown({required this.user});
  final UserProfile user;

  @override
  ConsumerState<_RoleDropdown> createState() => _RoleDropdownState();
}

class _RoleDropdownState extends ConsumerState<_RoleDropdown> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return PopupMenuButton<UserRole>(
      initialValue: widget.user.role,
      tooltip: 'Change role',
      icon: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurfaceVariant),
      itemBuilder: (context) => UserRole.values.map((role) {
        return PopupMenuItem(
          value: role,
          child: Text(role.name.toUpperCase()),
        );
      }).toList(),
      onSelected: (newRole) async {
        if (newRole == widget.user.role) return;

        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Change Role?'),
            content: Text(
                'Change this user\'s role to ${newRole.name.toUpperCase()}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        );

        if (confirm != true) return;

        setState(() => _isLoading = true);
        try {
          await ref
              .read(userRoleProvider.notifier)
              .updateRole(widget.user.uid, newRole);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Role updated to ${newRole.name}')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update role: $e')),
            );
          }
        } finally {
          if (mounted) setState(() => _isLoading = false);
        }
      },
    );
  }
}

// ── Pagination bar ────────────────────────────────────────────────────────────

class _UserPaginationBar extends StatelessWidget {
  const _UserPaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
    required this.onPageSelected,
  });

  final int page;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final start = (page * pageSize + 1).clamp(1, totalItems);
    final end = ((page + 1) * pageSize).clamp(1, totalItems);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Text(
            '$start–$end of $totalItems',
            style:
                TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: onPrev,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(36, 36),
                  ),
                ),
                ...List.generate(totalPages, (i) => i).where((i) {
                  if (totalPages <= 5) return true;
                  if (i == 0 || i == totalPages - 1) return true;
                  return (i - page).abs() <= 1;
                }).map(
                  (i) => SizedBox(
                    width: 32,
                    height: 32,
                    child: TextButton(
                      onPressed: () => onPageSelected(i),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor:
                            i == page ? cs.primary : Colors.transparent,
                        foregroundColor:
                            i == page ? cs.onPrimary : cs.onSurface,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('${i + 1}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: onNext,
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(6),
                    minimumSize: const Size(36, 36),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
