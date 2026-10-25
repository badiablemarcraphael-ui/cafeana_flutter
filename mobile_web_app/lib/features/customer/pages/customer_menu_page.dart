import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/providers/product_providers.dart';
import '../widgets/product_card.dart';

/// Displays all available products, grouped by category.
///
/// - Streams `availableProductsProvider` in real-time.
/// - Groups products by [Product.category] into section headers.
/// - FAB shows cart item count and navigates to `/customer/cart`.
class CustomerMenuPage extends ConsumerStatefulWidget {
  const CustomerMenuPage({super.key});

  @override
  ConsumerState<CustomerMenuPage> createState() => _CustomerMenuPageState();
}

class _CustomerMenuPageState extends ConsumerState<CustomerMenuPage> {
  String _selectedCategory = 'All';

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(availableProductsProvider);
    final cartCount = ref.watch(cartItemCountProvider);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'Could not load menu',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        data: (products) {
          if (products.isEmpty) {
            return CustomScrollView(
              slivers: [
                _buildSliverAppBar(context, isDark),
                const SliverFillRemaining(child: _EmptyMenu()),
              ],
            );
          }

          final grouped = _groupByCategory(products);
          final categories = grouped.keys.toList();

          final filteredGrouped = _selectedCategory.toLowerCase() == 'all'
              ? grouped
              : Map.fromEntries(
                  grouped.entries.where(
                    (e) =>
                        e.key.toLowerCase() == _selectedCategory.toLowerCase(),
                  ),
                );

          return CustomScrollView(
            slivers: [
              // ── Sliver App Bar ────────────────────────────────────────────
              _buildSliverAppBar(context, isDark),

              // ── Category chips scroll bar ─────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _CategoryChipsDelegate(
                  categories: categories,
                  selectedCategory: _selectedCategory,
                  onCategorySelected: (cat) {
                    setState(() {
                      _selectedCategory = cat;
                    });
                  },
                ),
              ),

              if (filteredGrouped.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.coffee_outlined,
                              size: 56,
                              color:
                                  cs.onSurfaceVariant.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text(
                            'No items in "$_selectedCategory"',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = 'All';
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Show All Items'),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                for (final entry in filteredGrouped.entries) ...[
                // ── Section header ─────────────────────────────────────────
                SliverPadding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 18,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [cs.primary, cs.tertiary],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _capitalize(entry.key),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Divider(
                            color: cs.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entry.value.length}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Product grid ──────────────────────────────────────────
                SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisExtent: 250,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = entry.value[index];
                        return ProductCard(product: product)
                            .animate()
                            .fadeIn(delay: (60 * index).ms)
                            .slideY(begin: 0.06, end: 0);
                      },
                      childCount: entry.value.length,
                    ),
                  ),
                ),
              ],

              // Bottom padding for FAB
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
      floatingActionButton: cartCount == 0
          ? null
          : _CartFab(cartCount: cartCount)
              .animate()
              .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: true,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: const Text('Menu'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(
          height: 1,
          color: isDark
              ? const Color(0xFFDCA87C).withValues(alpha: 0.20)
              : const Color(0xFFC88D5D).withValues(alpha: 0.28),
        ),
      ),
    );
  }

  Map<String, List<Product>> _groupByCategory(List<Product> products) {
    final map = <String, List<Product>>{};
    for (final p in products) {
      if (p.category.toLowerCase() == 'add-ons') continue;
      map.putIfAbsent(p.category, () => []).add(p);
    }
    return map;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Category chips header ─────────────────────────────────────────────────────

class _CategoryChipsDelegate extends SliverPersistentHeaderDelegate {
  _CategoryChipsDelegate({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final cs = Theme.of(context).colorScheme;
    final allCategories = ['All', ...categories];

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: allCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = allCategories[i];
          final isSelected =
              selectedCategory.toLowerCase() == cat.toLowerCase();
          final displayName = cat == 'All'
              ? 'All'
              : (cat.isNotEmpty
                  ? '${cat[0].toUpperCase()}${cat.substring(1)}'
                  : cat);

          return GestureDetector(
            onTap: () => onCategorySelected(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? cs.primary
                    : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? cs.primary
                      : cs.outlineVariant.withValues(alpha: 0.35),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  displayName,
                  style: TextStyle(
                    color: isSelected ? cs.onPrimary : cs.onSurface,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  bool shouldRebuild(_CategoryChipsDelegate oldDelegate) =>
      oldDelegate.categories != categories ||
      oldDelegate.selectedCategory != selectedCategory;
}

// ── Cart FAB ──────────────────────────────────────────────────────────────────

class _CartFab extends StatelessWidget {
  const _CartFab({required this.cartCount});
  final int cartCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(AppRoutes.customerCart),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2C2420), Color(0xFF40342E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2C2420).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Cart ($cartCount)',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Menu is empty',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back soon for new items.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
    );
  }
}
