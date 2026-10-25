import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../app/router.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/product_providers.dart';
import '../../customer/widgets/product_card.dart';

class LandingPage extends ConsumerStatefulWidget {
  const LandingPage({super.key});

  @override
  ConsumerState<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends ConsumerState<LandingPage> {
  final _homeKey = GlobalKey();
  final _aboutKey = GlobalKey();
  final _productKey = GlobalKey();
  final _categoryKey = GlobalKey();
  final _contactKey = GlobalKey();

  void _scrollTo(GlobalKey key) {
    if (key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(availableProductsProvider);
    final cs = Theme.of(context).colorScheme;
    
    // Check if the screen is wide (desktop/tablet) or narrow (mobile)
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.coffee, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              'Cafeana',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: cs.primary,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (isWide) ...[
            _NavBarLink(title: 'Home', onTap: () => _scrollTo(_homeKey)),
            _NavBarLink(title: 'About', onTap: () => _scrollTo(_aboutKey)),
            _NavBarLink(title: 'Menu', onTap: () => _scrollTo(_categoryKey)),
            _NavBarLink(title: 'Contact Us', onTap: () => _scrollTo(_contactKey)),
            const SizedBox(width: 24),
          ],
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: FilledButton(
              onPressed: () => context.go(AppRoutes.login),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: const Text('Login / Register', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (products) {
            final featured = products.where((p) => p.isFeatured).toList();
            final grouped = _groupByCategory(products);

            return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero Section ──
                Container(
                  key: _homeKey,
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 64.0 : 24.0,
                    vertical: isWide ? 80.0 : 40.0,
                  ),
                  child: Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Text Content
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enjoy The Most',
                              style: (isWide ? Theme.of(context).textTheme.displayLarge : Theme.of(context).textTheme.displaySmall)?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -1.5,
                                color: cs.onSurface,
                              ),
                            ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, end: 0),
                            Text(
                              'Delicious Coffee',
                              style: (isWide ? Theme.of(context).textTheme.displayLarge : Theme.of(context).textTheme.displaySmall)?.copyWith(
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                                letterSpacing: -1.5,
                                color: cs.primary,
                              ),
                            ).animate().fadeIn(duration: 600.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 24),
                            Text(
                              'Start Your Day With Coffee, Enhancing Productivity And Mood. '
                              'Its Invigorating Aroma Sets A Focused Tone For Tackling Tasks '
                              'With Renewed Energy And Positivity.',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Colors.black87,
                                height: 1.6,
                              ),
                            ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                            const SizedBox(height: 40),
                            Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: [
                                FilledButton(
                                  onPressed: () {
                                    if (featured.isNotEmpty) {
                                      _scrollTo(_productKey);
                                    } else {
                                      _scrollTo(_categoryKey);
                                    }
                                  },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: cs.onPrimary,
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Explore ↗', style: TextStyle(fontSize: 16)),
                                ),
                                OutlinedButton(
                                  onPressed: () => context.go(AppRoutes.login),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: cs.onSurface,
                                    side: BorderSide(color: cs.onSurface, width: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Order Coffee ☕', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ).animate().fadeIn(duration: 600.ms, delay: 600.ms),
                          ],
                        ),
                      ),
                      
                      if (isWide) const SizedBox(width: 64),
                      if (!isWide) const SizedBox(height: 48),
                      
                      // Hero Image Placeholder (Cup)
                      Expanded(
                        flex: isWide ? 1 : 0,
                        child: Center(
                          child: Container(
                            height: isWide ? 400 : 250,
                            width: isWide ? 400 : 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primaryContainer.withValues(alpha: 0.3),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withValues(alpha: 0.1),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                )
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.coffee,
                                  size: isWide ? 200 : 120,
                                  color: cs.primary.withValues(alpha: 0.8),
                                ),
                                Positioned(
                                  bottom: isWide ? 40 : 20,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: cs.surface,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: List.generate(5, (index) => const Icon(Icons.star, color: Colors.orange, size: 16)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text('4.9 Rating', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().scale(duration: 800.ms, curve: Curves.easeOutBack),
                      ),
                    ],
                  ),
                ),


                // ── Featured Products ──
                if (featured.isNotEmpty) ...[
                  Padding(
                    key: _productKey,
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 64.0 : 24.0, vertical: 24),
                    child: Text(
                      'Featured Products',
                      style: (isWide ? Theme.of(context).textTheme.headlineMedium : Theme.of(context).textTheme.titleLarge)?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 320,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 64.0 : 24.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: featured.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 24),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: 240,
                          child: ProductCard(
                            product: featured[index],
                            onTap: () => context.go(AppRoutes.login),
                          ).animate().fadeIn(delay: (100 * index).ms).slideX(begin: 0.1, end: 0),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],

                // ── Other Categories ──
                Padding(
                  key: _categoryKey,
                  padding: EdgeInsets.symmetric(horizontal: isWide ? 64.0 : 24.0, vertical: 24),
                  child: Text(
                    'Full Menu by Category',
                    style: (isWide ? Theme.of(context).textTheme.headlineMedium : Theme.of(context).textTheme.titleLarge)?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 64.0 : 24.0, vertical: 16),
                    child: Text(
                      _capitalize(entry.key),
                      style: (isWide ? Theme.of(context).textTheme.headlineSmall : Theme.of(context).textTheme.titleMedium)?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 320,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 64.0 : 24.0),
                      scrollDirection: Axis.horizontal,
                      itemCount: entry.value.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 24),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: 240,
                          child: ProductCard(
                            product: entry.value[index],
                            onTap: () => context.go(AppRoutes.login),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
                const SizedBox(height: 40),

                // ── About Us Section ──
                Container(
                  key: _aboutKey,
                  width: double.infinity,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 64.0 : 24.0,
                    vertical: isWide ? 80.0 : 40.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Our Story',
                        style: (isWide ? Theme.of(context).textTheme.headlineLarge : Theme.of(context).textTheme.headlineMedium)?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Text(
                          "Welcome to Cafeana! We started with a simple vision: to serve the perfect cup of coffee in a welcoming space. "
                          "Our beans are ethically sourced from local farmers and roasted right here in-house to ensure every sip delivers "
                          "that rich, invigorating aroma you love.\n\nWhether you're stopping by for your morning espresso, settling in to get "
                          "some work done, or catching up with old friends over a creamy mocha, we believe every cup tells a story. "
                          "Come be a part of ours.",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.black87,
                            height: 1.8,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── End of About Us Section ──

                // ── Contact Us Section (Footer) ──
                Container(
                  key: _contactKey,
                  width: double.infinity,
                  color: cs.surfaceContainerHigh,
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide ? 64.0 : 24.0,
                    vertical: isWide ? 64.0 : 40.0,
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    spacing: 40,
                    runSpacing: 40,
                    children: [
                      // Brand Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.coffee, color: cs.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Cafeana',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: cs.primary,
                                  fontSize: 24,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'The perfect brew\nfor a perfect day.',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      // Contact Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Contact Us',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _ContactRow(icon: Icons.location_on, text: '123 Coffee Street, Beansville, CA 90210'),
                          const SizedBox(height: 12),
                          _ContactRow(icon: Icons.phone, text: '+1 (555) 123-4567'),
                          const SizedBox(height: 12),
                          _ContactRow(icon: Icons.email, text: 'hello@cafeana.com'),
                        ],
                      ),
                      // Hours Column
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Opening Hours',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('Mon - Fri: 7:00 AM - 8:00 PM', style: TextStyle(color: Colors.black87)),
                          const SizedBox(height: 8),
                          Text('Sat - Sun: 8:00 AM - 9:00 PM', style: TextStyle(color: Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
          },
        ),
    );
  }

  Map<String, List<Product>> _groupByCategory(List<Product> products) {
    final map = <String, List<Product>>{};
    for (final p in products) {
      if (p.category.toLowerCase() == 'add-ons') continue; // Don't show add-ons as a main category
      map.putIfAbsent(p.category, () => []).add(p);
    }
    return map;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ContactRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _NavBarLink extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  const _NavBarLink({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}
