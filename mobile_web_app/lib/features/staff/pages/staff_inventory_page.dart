import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/models/ingredient.dart';
import '../../../core/models/product.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/utils/export_csv_util.dart';
import '../../../core/widgets/animated_glass_card.dart';

// ── Shared helpers ────────────────────────────────────────────────────────────

final _qtyFmt = NumberFormat('#,##0.##');

/// Formats an amount with up to 2 decimals and thousands separators.
String _fmt(double v) => _qtyFmt.format(v);

const _presetCategories = [
  'Coffee',
  'Dairy',
  'Powder',
  'Sauce',
  'Syrup',
  'Fruit',
  'Beverage',
  'Packaging',
  'Ice',
  'Other',
];

const _presetUnits = ['g', 'ml', 'set', 'pc'];

const _presetContainers = [
  'pack',
  'bottle',
  'bag',
  'can',
  'carton',
  'jar',
  'box',
  'sleeve',
  'gallon',
];

IconData _iconForCategory(String cat) {
  return switch (cat.toLowerCase()) {
    'coffee' => Icons.coffee_rounded,
    'dairy' => Icons.local_drink_rounded,
    'powder' => Icons.grain_rounded,
    'sauce' => Icons.water_drop_rounded,
    'syrup' => Icons.liquor_rounded,
    'fruit' => Icons.eco_rounded,
    'beverage' => Icons.bubble_chart_rounded,
    'packaging' => Icons.takeout_dining_rounded,
    'ice' => Icons.ac_unit_rounded,
    _ => Icons.inventory_2_outlined,
  };
}

/// How many drinks of a given recipe can be made from current stock.
/// Returns null when the recipe is empty.
int? _servingsPossible(List<RecipeItem> recipe, Map<String, Ingredient> byId) {
  int? result;
  for (final r in recipe) {
    if (r.quantity <= 0 || r.ingredientId.isEmpty) continue;
    final ing = byId[r.ingredientId];
    final possible = ing == null ? 0 : (ing.stockLevel / r.quantity).floor();
    result = result == null ? possible : (possible < result ? possible : result);
  }
  return result;
}

final _decimalInput = [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))];

// ── Page ──────────────────────────────────────────────────────────────────────

class StaffInventoryPage extends ConsumerStatefulWidget {
  const StaffInventoryPage({super.key});

  @override
  ConsumerState<StaffInventoryPage> createState() => _StaffInventoryPageState();
}

class _StaffInventoryPageState extends ConsumerState<StaffInventoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _stockSearchCtrl = TextEditingController();
  final _recipeSearchCtrl = TextEditingController();
  String _stockQuery = '';
  String _recipeQuery = '';
  String _stockCategory = 'All';
  String _recipeCategory = 'All';
  bool _lowOnly = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _stockSearchCtrl.dispose();
    _recipeSearchCtrl.dispose();
    super.dispose();
  }

  // ── Dialog launchers ────────────────────────────────────────────────────────

  void _openIngredientForm(List<Ingredient> all, {Ingredient? existing}) {
    showDialog(
      context: context,
      builder: (_) => _IngredientFormDialog(allIngredients: all, existing: existing),
    );
  }

  void _openAdjust(Ingredient ing) {
    showDialog(
      context: context,
      builder: (_) => _AdjustStockDialog(ingredient: ing),
    );
  }

  void _openRecipeEditor(Product product, List<Ingredient> ingredients) {
    showDialog(
      context: context,
      builder: (_) => _RecipeEditorDialog(product: product, ingredients: ingredients),
    );
  }

  Future<void> _confirmDelete(Ingredient ing, List<Product> products) async {
    final usedIn = products
        .where((p) =>
            p.recipe.any((r) => r.ingredientId == ing.id) ||
            p.recipeSmall.any((r) => r.ingredientId == ing.id))
        .map((p) => p.name)
        .toList();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${ing.name}?'),
        content: Text(
          usedIn.isEmpty
              ? 'This removes the ingredient from the database.'
              : 'This ingredient is used in ${usedIn.length} recipe(s): '
                  '${usedIn.take(5).join(', ')}${usedIn.length > 5 ? '…' : ''}.\n\n'
                  'Orders for those drinks will no longer deduct it. Delete anyway?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(ingredientCrudProvider.notifier).deleteIngredient(ing.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ing.name} deleted')),
      );
    }
  }

  Future<void> _runExport(String label, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text('Exporting $label...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      await action();
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text('$label exported successfully.'),
            ],
          ),
        ),
      );
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('Export failed: $e'),
        ),
      );
    }
  }

  void _showExportDialog(
    BuildContext context,
    List<Ingredient> ingredients,
    List<Product> products,
  ) {
    final lowCount = ingredients.where((i) => i.isLowStock).length;
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.file_download_outlined, color: cs.onPrimaryContainer, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    'Download operational CSV spreadsheets',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ExportOptionTile(
                icon: Icons.table_chart_rounded,
                iconColor: Colors.blueAccent,
                title: 'Full Master Inventory (CSV)',
                subtitle: 'All stock holdings, pack specs, 12 oz & 16 oz recipes, and drink prep capacity.',
                onTap: () async {
                  Navigator.pop(ctx);
                  _runExport(
                    'Full Master Inventory',
                    () => ExportCsvUtil.exportFullInventoryReport(
                      ingredients: ingredients,
                      products: products,
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _ExportOptionTile(
                icon: Icons.inventory_2_rounded,
                iconColor: Colors.teal,
                title: 'Stock Holdings & Pack Count (CSV)',
                subtitle: 'All raw materials, container types, pack sizes, and manual audit counting columns.',
                onTap: () async {
                  Navigator.pop(ctx);
                  _runExport(
                    'Stock Holdings',
                    () => ExportCsvUtil.exportStockHoldingsCsv(
                      ingredients: ingredients,
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _ExportOptionTile(
                icon: Icons.local_cafe_rounded,
                iconColor: Colors.deepOrangeAccent,
                title: 'Drink Recipes BOM (CSV)',
                subtitle: 'Kitchen recipe bills of materials for Small (12 oz) and Large (16 oz) side-by-side.',
                onTap: () async {
                  Navigator.pop(ctx);
                  _runExport(
                    'Drink Recipes BOM',
                    () => ExportCsvUtil.exportDrinkRecipesCsv(
                      products: products,
                      ingredients: ingredients,
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              _ExportOptionTile(
                icon: Icons.warning_amber_rounded,
                iconColor: Colors.orange,
                badge: lowCount > 0 ? '$lowCount low' : null,
                title: 'Low Stock Restock List (CSV)',
                subtitle: 'Items at or below safety threshold with deficit and recommended reorder packs.',
                onTap: () async {
                  Navigator.pop(ctx);
                  _runExport(
                    'Low Stock Restock List',
                    () => ExportCsvUtil.exportLowStockRestockList(
                      ingredients: ingredients,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ingredientsAsync = ref.watch(allIngredientsProvider);
    final productsAsync = ref.watch(allProductsProvider);
    final ingredients = ingredientsAsync.valueOrNull ?? const <Ingredient>[];
    final products = (productsAsync.valueOrNull ?? const <Product>[])
        .where((p) => p.category.toLowerCase() != 'add-ons')
        .toList();
    final cs = Theme.of(context).colorScheme;

    final lowCount = ingredients.where((i) => i.isLowStock).length;
    final withRecipe = products.where((p) => p.recipe.isNotEmpty).length;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Inventory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              'Ingredients • Pack sizes • Small 12 oz / Large 16 oz recipes',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Inventory CSV',
            onPressed: ingredients.isEmpty && products.isEmpty
                ? null
                : () => _showExportDialog(context, ingredients, products),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: [
            Tab(icon: const Icon(Icons.inventory_2_outlined), text: 'Stock (${ingredients.length})'),
            Tab(icon: const Icon(Icons.local_cafe_outlined), text: 'Drink Recipes (${products.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_ingredient_fab',
        onPressed: () => _openIngredientForm(ingredients),
        icon: const Icon(Icons.add),
        label: const Text('Add Ingredient'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primaryContainer.withValues(alpha: 0.25),
              cs.surface,
              cs.secondaryContainer.withValues(alpha: 0.15),
            ],
          ),
        ),
        child: Column(
          children: [
            _SummaryStrip(
              ingredientCount: ingredients.length,
              lowCount: lowCount,
              drinksWithRecipe: withRecipe,
              drinkCount: products.length,
              onLowTap: () {
                _tabCtrl.animateTo(0);
                setState(() => _lowOnly = true);
              },
              onExportTap: () => _showExportDialog(context, ingredients, products),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _buildStockTab(ingredientsAsync, products),
                  _buildRecipesTab(productsAsync, products, ingredients),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Stock ────────────────────────────────────────────────────────────

  Widget _buildStockTab(AsyncValue<List<Ingredient>> async, List<Product> products) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading ingredients: $e')),
      data: (ingredients) {
        if (ingredients.isEmpty) {
          return _EmptyState(
            icon: Icons.inventory_2_outlined,
            message: 'No ingredients in the database yet.',
            primaryLabel: 'Add Ingredient',
            onPrimary: () => _openIngredientForm(ingredients),
          );
        }

        final categories = ['All', ...{...ingredients.map((i) => i.category)}];
        final q = _stockQuery.toLowerCase();
        final filtered = ingredients.where((i) {
          if (_lowOnly && !i.isLowStock) return false;
          if (_stockCategory != 'All' && i.category != _stockCategory) return false;
          if (q.isEmpty) return true;
          return i.name.toLowerCase().contains(q) ||
              i.id.toLowerCase().contains(q) ||
              i.category.toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                      label: const Text('Low stock'),
                      selected: _lowOnly,
                      onSelected: (v) => setState(() => _lowOnly = v),
                    ),
                  ),
                  for (final cat in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: cat == _stockCategory,
                        onSelected: (_) => setState(() => _stockCategory = cat),
                      ),
                    ),
                ],
              ),
            ),
            _SearchField(
              controller: _stockSearchCtrl,
              hint: 'Search ingredient by name, ID or category...',
              onChanged: (v) => setState(() => _stockQuery = v),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matching ingredients.'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final ing = filtered[index];
                        return _IngredientStockCard(
                          ingredient: ing,
                          onAdjust: () => _openAdjust(ing),
                          onEdit: () => _openIngredientForm(ingredients, existing: ing),
                          onDelete: () => _confirmDelete(ing, products),
                        ).animate().fadeIn(delay: (15 * index).ms).slideY(begin: 0.04, end: 0);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  // ── Tab 2: Recipes ──────────────────────────────────────────────────────────

  Widget _buildRecipesTab(
    AsyncValue<List<Product>> async,
    List<Product> products,
    List<Ingredient> ingredients,
  ) {
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading drinks: $e')),
      data: (_) {
        if (products.isEmpty) {
          return const _EmptyState(
            icon: Icons.local_cafe_outlined,
            message: 'No drinks found in the menu.',
          );
        }

        final byId = {for (final i in ingredients) i.id: i};
        final categories = ['All', ...{...products.map((p) => p.category)}];
        final q = _recipeQuery.toLowerCase();
        final filtered = products.where((p) {
          if (_recipeCategory != 'All' && p.category != _recipeCategory) return false;
          if (q.isEmpty) return true;
          return p.name.toLowerCase().contains(q) ||
              (p.itemId ?? '').toLowerCase().contains(q) ||
              p.recipe.any((r) => r.name.toLowerCase().contains(q));
        }).toList()
          ..sort((a, b) => (a.itemId ?? 'Z${a.name}').compareTo(b.itemId ?? 'Z${b.name}'));

        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  for (final cat in categories)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: cat == _recipeCategory,
                        onSelected: (_) => setState(() => _recipeCategory = cat),
                      ),
                    ),
                ],
              ),
            ),
            _SearchField(
              controller: _recipeSearchCtrl,
              hint: 'Search drink or ingredient...',
              onChanged: (v) => setState(() => _recipeQuery = v),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 1100
                      ? 3
                      : constraints.maxWidth > 720
                          ? 2
                          : 1;
                  const spacing = 12.0;
                  final itemWidth =
                      (constraints.maxWidth - 32 - spacing * (columns - 1)) / columns;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    child: Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (var i = 0; i < filtered.length; i++)
                          SizedBox(
                            width: itemWidth,
                            child: _DrinkRecipeCard(
                              product: filtered[i],
                              ingredientsById: byId,
                              onEdit: () => _openRecipeEditor(filtered[i], ingredients),
                            ).animate().fadeIn(delay: (15 * i).ms),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Summary strip ─────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.ingredientCount,
    required this.lowCount,
    required this.drinksWithRecipe,
    required this.drinkCount,
    required this.onLowTap,
    this.onExportTap,
  });

  final int ingredientCount;
  final int lowCount;
  final int drinksWithRecipe;
  final int drinkCount;
  final VoidCallback onLowTap;
  final VoidCallback? onExportTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _StatTile(
            icon: Icons.inventory_2_rounded,
            label: 'INGREDIENTS',
            value: '$ingredientCount',
            color: Colors.blueAccent,
          ),
          _StatTile(
            icon: Icons.warning_amber_rounded,
            label: 'LOW STOCK',
            value: '$lowCount',
            color: lowCount > 0 ? Colors.orange : Colors.green,
            onTap: lowCount > 0 ? onLowTap : null,
          ),
          _StatTile(
            icon: Icons.receipt_long_rounded,
            label: 'DRINKS WITH RECIPE',
            value: '$drinksWithRecipe / $drinkCount',
            color: Colors.teal,
          ),
          _StatTile(
            icon: Icons.file_download_outlined,
            label: 'EXPORT CSV',
            value: 'Download',
            color: Colors.indigoAccent,
            onTap: onExportTap,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 170,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
  });

  final IconData icon;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message),
          if (primaryLabel != null && onPrimary != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(icon: const Icon(Icons.add), label: Text(primaryLabel!), onPressed: onPrimary),
          ],
        ],
      ),
    );
  }
}

// ── Ingredient stock card ─────────────────────────────────────────────────────

class _IngredientStockCard extends StatelessWidget {
  const _IngredientStockCard({
    required this.ingredient,
    required this.onAdjust,
    required this.onEdit,
    required this.onDelete,
  });

  final Ingredient ingredient;
  final VoidCallback onAdjust;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ing = ingredient;
    final isLow = ing.isLowStock;
    final accent = isLow ? Colors.orange : cs.primary;
    // Bar is "full" at 3x the low-stock threshold.
    final barTarget = ing.minStockLevel > 0 ? ing.minStockLevel * 3 : ing.packQuantity * 3;
    final barValue = barTarget > 0 ? (ing.stockLevel / barTarget).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedGlassCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        onTap: onAdjust,
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: accent.withValues(alpha: 0.15),
              child: Icon(_iconForCategory(ing.category), color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          ing.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.outlineVariant.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(ing.id, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${ing.category} • 1 ${ing.packContainer} = ${_fmt(ing.packQuantity)} ${ing.unit}',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: barValue,
                      minHeight: 6,
                      color: accent,
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Alert at ${_fmt(ing.minPacks)} ${ing.packContainer}(s) • ${_fmt(ing.minStockLevel)} ${ing.unit}',
                    style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_fmt(ing.packsOnHand)} ${ing.packContainer}s',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: accent),
                ),
                Text(
                  '${_fmt(ing.stockLevel)} ${ing.unit}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                ),
                if (isLow)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LOW STOCK',
                      style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
            PopupMenuButton<String>(
              tooltip: 'Options',
              onSelected: (v) => switch (v) {
                'adjust' => onAdjust(),
                'edit' => onEdit(),
                'delete' => onDelete(),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'adjust',
                  child: ListTile(leading: Icon(Icons.swap_vert), title: Text('Restock / Use')),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit details')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline, color: Colors.red),
                    title: Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Drink recipe card (Small / Large) ─────────────────────────────────────────

class _DrinkRecipeCard extends StatelessWidget {
  const _DrinkRecipeCard({
    required this.product,
    required this.ingredientsById,
    required this.onEdit,
  });

  final Product product;
  final Map<String, Ingredient> ingredientsById;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final large = product.recipeFor(DrinkSize.large);
    final small = product.recipeFor(DrinkSize.small);
    final hasRecipe = large.isNotEmpty || small.isNotEmpty;

    // Merge both sizes into one table, keyed by ingredient.
    final order = <String>[];
    final names = <String, String>{};
    final units = <String, String>{};
    final smallQty = <String, double>{};
    final largeQty = <String, double>{};
    void collect(List<RecipeItem> items, Map<String, double> target) {
      for (final r in items) {
        if (!order.contains(r.ingredientId)) order.add(r.ingredientId);
        names[r.ingredientId] = r.name;
        units[r.ingredientId] = r.unit;
        target[r.ingredientId] = (target[r.ingredientId] ?? 0) + r.quantity;
      }
    }

    collect(large, largeQty);
    collect(small, smallQty);

    final canSmall = _servingsPossible(small, ingredientsById);
    final canLarge = _servingsPossible(large, ingredientsById);

    const headerStyle = TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.3);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [if (product.itemId != null) product.itemId!, product.category].join(' • '),
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (product.isSmallAutoScaled)
                  Tooltip(
                    message: 'Small amounts are auto-calculated at 75% of Large. Tap edit to set exact amounts.',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'S = AUTO 75%',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.orange),
                      ),
                    ),
                  ),
                IconButton(
                  tooltip: 'Edit recipe',
                  icon: Icon(hasRecipe ? Icons.edit_outlined : Icons.add_circle_outline, color: cs.primary),
                  onPressed: onEdit,
                ),
              ],
            ),
          ),

          if (!hasRecipe)
            InkWell(
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_outlined, color: cs.onSurfaceVariant),
                    const SizedBox(height: 6),
                    Text(
                      'No recipe yet — tap to add the Small & Large amounts',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Table header
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: Row(
                children: [
                  Expanded(child: Text('INGREDIENT', style: headerStyle.copyWith(color: cs.onSurfaceVariant))),
                  SizedBox(
                    width: 74,
                    child: Text('SMALL 12oz', textAlign: TextAlign.right, style: headerStyle.copyWith(color: cs.secondary)),
                  ),
                  SizedBox(
                    width: 74,
                    child: Text('LARGE 16oz', textAlign: TextAlign.right, style: headerStyle.copyWith(color: cs.primary)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 14, endIndent: 14),
            for (final id in order)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        names[id] ?? id,
                        style: TextStyle(
                          fontSize: 13,
                          color: ingredientsById[id]?.isLowStock == true ? Colors.orange : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(
                      width: 74,
                      child: Text(
                        smallQty[id] != null ? '${_fmt(smallQty[id]!)} ${units[id]}' : '—',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 74,
                      child: Text(
                        largeQty[id] != null ? '${_fmt(largeQty[id]!)} ${units[id]}' : '—',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            // Footer: how many can be made from current stock
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4))),
              ),
              child: Row(
                children: [
                  Icon(Icons.local_cafe_outlined, size: 15, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Can make from stock',
                      style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                    ),
                  ),
                  SizedBox(
                    width: 74,
                    child: Text(
                      canSmall == null ? '—' : '$canSmall',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.w800, color: cs.secondary),
                    ),
                  ),
                  SizedBox(
                    width: 74,
                    child: Text(
                      canLarge == null ? '—' : '$canLarge',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontWeight: FontWeight.w800, color: cs.primary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Add / Edit ingredient dialog ──────────────────────────────────────────────

class _IngredientFormDialog extends ConsumerStatefulWidget {
  const _IngredientFormDialog({required this.allIngredients, this.existing});

  final List<Ingredient> allIngredients;
  final Ingredient? existing;

  @override
  ConsumerState<_IngredientFormDialog> createState() => _IngredientFormDialogState();
}

class _IngredientFormDialogState extends ConsumerState<_IngredientFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _idCtrl;
  late final TextEditingController _packAmountCtrl;
  late final TextEditingController _packsCtrl;
  late final TextEditingController _looseCtrl;
  late final TextEditingController _alertPacksCtrl;
  late String _category;
  late String _unit;
  late String _container;
  late final List<String> _categories;
  late final List<String> _containers;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  String _suggestId() {
    var maxNum = 0;
    for (final i in widget.allIngredients) {
      final m = RegExp(r'^ING(\d+)$').firstMatch(i.id);
      if (m != null) {
        final n = int.parse(m.group(1)!);
        if (n > maxNum) maxNum = n;
      }
    }
    return 'ING${(maxNum + 1).toString().padLeft(3, '0')}';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;

    _categories = {..._presetCategories, ...widget.allIngredients.map((i) => i.category)}.toList();
    _category = e?.category ?? 'Syrup';
    if (!_categories.contains(_category)) _categories.add(_category);

    _unit = e?.unit ?? 'ml';
    _containers = [..._presetContainers];
    _container = e?.packContainer ?? 'bottle';
    if (!_containers.contains(_container)) _containers.add(_container);

    // Split existing stock into whole packs + loose amount so nothing is lost to rounding.
    String packsText = '';
    String looseText = '';
    if (e != null) {
      final whole = (e.stockLevel / e.packQuantity).floor();
      final loose = e.stockLevel - whole * e.packQuantity;
      packsText = '$whole';
      looseText = loose > 0.0001 ? _trim(loose) : '';
    }

    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _idCtrl = TextEditingController(text: e?.id ?? _suggestId());
    _packAmountCtrl = TextEditingController(text: e != null ? _trim(e.packQuantity) : '');
    _packsCtrl = TextEditingController(text: packsText);
    _looseCtrl = TextEditingController(text: looseText);
    _alertPacksCtrl = TextEditingController(text: e != null ? _trim(e.minPacks) : '1');
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : double.parse(v.toStringAsFixed(3)).toString();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _idCtrl.dispose();
    _packAmountCtrl.dispose();
    _packsCtrl.dispose();
    _looseCtrl.dispose();
    _alertPacksCtrl.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final packAmount = _num(_packAmountCtrl);
    final total = _num(_packsCtrl) * packAmount + _num(_looseCtrl);
    final alertTotal = _num(_alertPacksCtrl) * packAmount;

    return AlertDialog(
      title: Row(
        children: [
          Icon(_isEdit ? Icons.edit_outlined : Icons.add_box_outlined, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(_isEdit ? 'Edit ${widget.existing!.name}' : 'Add Ingredient')),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: !_isEdit,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Ingredient name *',
                    hintText: 'e.g. Hazelnut Syrup',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _idCtrl,
                        enabled: !_isEdit,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'ID',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          if (_isEdit) return null;
                          final id = (v ?? '').trim();
                          if (id.isEmpty) return 'Enter an ID';
                          if (id.contains('/')) return 'No "/" allowed';
                          if (widget.allIngredients.any((i) => i.id == id)) return 'ID already used';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _category,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final c in _categories) DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setState(() => _category = v ?? _category),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Measured in', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                SegmentedButton<String>(
                  segments: [
                    for (final u in _presetUnits) ButtonSegment(value: u, label: Text(u)),
                  ],
                  selected: {_presetUnits.contains(_unit) ? _unit : _presetUnits.first},
                  onSelectionChanged: (s) => setState(() => _unit = s.first),
                ),
                const SizedBox(height: 16),
                Text('Pack size (how much is in ONE pack)', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _packAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: _decimalInput,
                        decoration: InputDecoration(
                          labelText: 'Amount per pack *',
                          hintText: 'e.g. 750',
                          suffixText: _unit,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            (double.tryParse(v?.trim() ?? '') ?? 0) <= 0 ? 'Must be > 0' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _container,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Pack type',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          for (final c in _containers) DropdownMenuItem(value: c, child: Text(c)),
                        ],
                        onChanged: (v) => setState(() => _container = v ?? _container),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Stock on hand', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _packsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: _decimalInput,
                        decoration: InputDecoration(
                          labelText: 'Full ${_container}s',
                          hintText: '0',
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _looseCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: _decimalInput,
                        decoration: InputDecoration(
                          labelText: '+ Opened / loose',
                          hintText: '0',
                          suffixText: _unit,
                          border: const OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _alertPacksCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: _decimalInput,
                  decoration: InputDecoration(
                    labelText: 'Low-stock alert when at or below',
                    suffixText: '${_container}s',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '1 $_container = ${_fmt(packAmount)} $_unit',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Total saved to database: ${_fmt(total)} $_unit'
                        '${packAmount > 0 ? ' (${_fmt(total / packAmount)} ${_container}s)' : ''}',
                      ),
                      Text('Alert at: ${_fmt(alertTotal)} $_unit'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(_isEdit ? 'Save Changes' : 'Add to Database'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final packAmount = _num(_packAmountCtrl);
    final stock = _num(_packsCtrl) * packAmount + _num(_looseCtrl);
    final minStock = _num(_alertPacksCtrl) * packAmount;
    final e = widget.existing;

    final ing = Ingredient(
      id: e?.id ?? _idCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      category: _category,
      packSize: '${_trim(packAmount)} $_unit $_container',
      packQuantity: packAmount,
      unit: _unit,
      unitCost: e?.unitCost ?? 0,
      stockLevel: stock,
      minStockLevel: minStock,
    );

    setState(() => _saving = true);
    final notifier = ref.read(ingredientCrudProvider.notifier);
    if (_isEdit) {
      await notifier.updateIngredient(ing);
    } else {
      await notifier.addIngredient(ing);
    }
    if (!mounted) return;

    final result = ref.read(ingredientCrudProvider);
    if (result.hasError) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: ${result.error}'), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ing.name} ${_isEdit ? 'updated' : 'added'} (${_fmt(stock)} ${ing.unit})'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

// ── Restock / Use dialog ──────────────────────────────────────────────────────

class _AdjustStockDialog extends ConsumerStatefulWidget {
  const _AdjustStockDialog({required this.ingredient});
  final Ingredient ingredient;

  @override
  ConsumerState<_AdjustStockDialog> createState() => _AdjustStockDialogState();
}

class _AdjustStockDialogState extends ConsumerState<_AdjustStockDialog> {
  final _amountCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _isAddition = true;
  bool _inPacks = true;
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  double get _delta {
    final raw = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final base = _inPacks ? raw * widget.ingredient.packQuantity : raw;
    return _isAddition ? base : -base;
  }

  @override
  Widget build(BuildContext context) {
    final ing = widget.ingredient;
    final cs = Theme.of(context).colorScheme;
    final newStock = (ing.stockLevel + _delta).clamp(0.0, double.infinity);

    return AlertDialog(
      title: Text(ing.name),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '1 ${ing.packContainer} = ${_fmt(ing.packQuantity)} ${ing.unit}',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            Text(
              'Now: ${_fmt(ing.stockLevel)} ${ing.unit} (${_fmt(ing.packsOnHand)} ${ing.packContainer}s)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Restock'), icon: Icon(Icons.add)),
                ButtonSegment(value: false, label: Text('Use / Waste'), icon: Icon(Icons.remove)),
              ],
              selected: {_isAddition},
              onSelectionChanged: (s) => setState(() => _isAddition = s.first),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _decimalInput,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: true, label: Text('${ing.packContainer}s')),
                    ButtonSegment(value: false, label: Text(ing.unit)),
                  ],
                  selected: {_inPacks},
                  onSelectionChanged: (s) => setState(() => _inPacks = s.first),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Supplier delivery, Spoilage, Count correction',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_isAddition ? Colors.green : Colors.orange).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'New stock: ${_fmt(newStock)} ${ing.unit} '
                '(${_fmt(newStock / ing.packQuantity)} ${ing.packContainer}s)',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save to Database'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final delta = _delta;
    if (delta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than 0')),
      );
      return;
    }
    final reason = _reasonCtrl.text.trim().isEmpty
        ? (_isAddition ? 'Restock' : 'Usage / waste')
        : _reasonCtrl.text.trim();

    setState(() => _saving = true);
    await ref.read(ingredientAdjustProvider.notifier).adjust(
          ingredient: widget.ingredient,
          delta: delta,
          reason: reason,
        );
    if (mounted) Navigator.pop(context);
  }
}

// ── Recipe editor (Small 12 oz / Large 16 oz) ─────────────────────────────────

class _RecipeRow {
  _RecipeRow({this.ingredientId, double? small, double? large})
      : small = TextEditingController(text: small == null || small == 0 ? '' : _RecipeRow.trim(small)),
        large = TextEditingController(text: large == null || large == 0 ? '' : _RecipeRow.trim(large));

  String? ingredientId;
  final TextEditingController small;
  final TextEditingController large;

  static String trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : double.parse(v.toStringAsFixed(2)).toString();

  double get smallQty => double.tryParse(small.text.trim()) ?? 0;
  double get largeQty => double.tryParse(large.text.trim()) ?? 0;

  void dispose() {
    small.dispose();
    large.dispose();
  }
}

class _RecipeEditorDialog extends ConsumerStatefulWidget {
  const _RecipeEditorDialog({required this.product, required this.ingredients});

  final Product product;
  final List<Ingredient> ingredients;

  @override
  ConsumerState<_RecipeEditorDialog> createState() => _RecipeEditorDialogState();
}

class _RecipeEditorDialogState extends ConsumerState<_RecipeEditorDialog> {
  final List<_RecipeRow> _rows = [];
  late final Map<String, Ingredient> _byId;
  late final Map<String, RecipeItem> _originalItems;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _byId = {for (final i in widget.ingredients) i.id: i};

    final large = widget.product.recipeFor(DrinkSize.large);
    final small = widget.product.recipeFor(DrinkSize.small);
    _originalItems = {for (final r in [...large, ...small]) r.ingredientId: r};

    final ids = <String>[];
    for (final r in [...large, ...small]) {
      if (!ids.contains(r.ingredientId)) ids.add(r.ingredientId);
    }
    double sumFor(List<RecipeItem> items, String id) =>
        items.where((r) => r.ingredientId == id).fold(0.0, (s, r) => s + r.quantity);
    for (final id in ids) {
      _rows.add(_RecipeRow(ingredientId: id, small: sumFor(small, id), large: sumFor(large, id)));
    }
    if (_rows.isEmpty) {
      if (widget.product.name.toLowerCase().contains('biscoff')) {
        _rows.addAll([
          _RecipeRow(ingredientId: 'ING001', small: 9, large: 18),
          _RecipeRow(ingredientId: 'ING010', small: 150, large: 200),
          _RecipeRow(ingredientId: 'ING070', small: 25, large: 35),
          _RecipeRow(ingredientId: 'ING071', small: 8, large: 12),
          _RecipeRow(ingredientId: 'ING081', small: 120, large: 160),
          _RecipeRow(ingredientId: 'ING080', small: 0, large: 1),
          _RecipeRow(ingredientId: 'ING082', small: 1, large: 0),
        ]);
      } else {
        _rows.add(_RecipeRow());
      }
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  String _unitOf(String? id) => _byId[id]?.unit ?? _originalItems[id]?.unit ?? '';

  /// Fills Small from Large at 75% (12 oz / 16 oz). Countable items keep the
  /// same count and the 16 oz cup is replaced by the 12 oz cup.
  void _autoFillSmall() {
    setState(() {
      for (final row in List<_RecipeRow>.from(_rows)) {
        final id = row.ingredientId;
        final large = row.largeQty;
        if (id == null || large <= 0) continue;
        if (id == Product.largeCupId) {
          row.small.text = '';
          var cupRow = _rows.where((r) => r.ingredientId == Product.smallCupId).firstOrNull;
          if (cupRow == null) {
            cupRow = _RecipeRow(ingredientId: Product.smallCupId);
            _rows.add(cupRow);
          }
          cupRow.small.text = _RecipeRow.trim(large);
          continue;
        }
        final unit = _unitOf(id).toLowerCase();
        final scaled = const {'set', 'unit', 'pc', 'pcs'}.contains(unit)
            ? large
            : (large * 0.75 * 10).roundToDouble() / 10;
        row.small.text = _RecipeRow.trim(scaled);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sortedIngredients = [...widget.ingredients]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.product.name} — Recipe'),
          const SizedBox(height: 4),
          Text(
            'Enter the exact amount of each ingredient per cup. Leave a size empty if it is not used.',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.normal, color: cs.onSurfaceVariant),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              for (var i = 0; i < _rows.length; i++) _buildRow(i, sortedIngredients, cs),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add ingredient'),
                    onPressed: () => setState(() => _rows.add(_RecipeRow())),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.auto_fix_high_outlined),
                    label: const Text('Auto-fill Small from Large (75%)'),
                    onPressed: _autoFillSmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_upload_outlined, size: 18),
          label: const Text('Save to Database'),
        ),
      ],
    );
  }

  Widget _buildRow(int index, List<Ingredient> sortedIngredients, ColorScheme cs) {
    final row = _rows[index];
    final unit = _unitOf(row.ingredientId);
    final knownIds = sortedIngredients.map((i) => i.id).toSet();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: row.ingredientId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ingredient',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    if (row.ingredientId != null && !knownIds.contains(row.ingredientId))
                      DropdownMenuItem(
                        value: row.ingredientId,
                        child: Text(
                          '${_originalItems[row.ingredientId]?.name ?? row.ingredientId} (not in stock list)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    for (final ing in sortedIngredients)
                      DropdownMenuItem(
                        value: ing.id,
                        child: Text('${ing.name} (${ing.unit})', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => row.ingredientId = v),
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => setState(() {
                  _rows.removeAt(index).dispose();
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.small,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _decimalInput,
                    decoration: InputDecoration(
                      labelText: 'Small 12 oz',
                      suffixText: unit,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.large,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: _decimalInput,
                    decoration: InputDecoration(
                      labelText: 'Large 16 oz',
                      suffixText: unit,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  RecipeItem _itemFor(String id, double qty) {
    final ing = _byId[id];
    final orig = _originalItems[id];
    return RecipeItem(
      ingredientId: id,
      name: ing?.name ?? orig?.name ?? id,
      quantity: qty,
      unit: ing?.unit ?? orig?.unit ?? 'g',
      unitCost: ing?.unitCost ?? orig?.unitCost ?? 0,
    );
  }

  Future<void> _save() async {
    final large = <RecipeItem>[];
    final small = <RecipeItem>[];
    final seen = <String>{};

    for (final row in _rows) {
      final hasQty = row.smallQty > 0 || row.largeQty > 0;
      if (row.ingredientId == null) {
        if (hasQty) {
          _error('Pick an ingredient for every row that has an amount.');
          return;
        }
        continue;
      }
      if (!seen.add(row.ingredientId!)) {
        _error('${_byId[row.ingredientId]?.name ?? row.ingredientId} is listed twice. Combine it into one row.');
        return;
      }
      if (row.largeQty > 0) large.add(_itemFor(row.ingredientId!, row.largeQty));
      if (row.smallQty > 0) small.add(_itemFor(row.ingredientId!, row.smallQty));
    }

    if (large.isEmpty && small.isNotEmpty) {
      _error('Add the Large (16 oz) amounts too.');
      return;
    }

    setState(() => _saving = true);
    await ref.read(productCrudProvider.notifier).updateRecipes(
          product: widget.product,
          large: large,
          small: small,
        );
    if (!mounted) return;

    final result = ref.read(productCrudProvider);
    if (result.hasError) {
      setState(() => _saving = false);
      _error('Save failed: ${result.error}');
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.product.name} recipe saved (Small ${small.length} / Large ${large.length} items)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: iconColor.withValues(alpha: 0.15),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
              ),
              child: Text(
                badge!,
                style: const TextStyle(
                  color: Colors.deepOrange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}
