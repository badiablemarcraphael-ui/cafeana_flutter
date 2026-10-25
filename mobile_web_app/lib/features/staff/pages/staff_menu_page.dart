import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/models/product.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/widgets/animated_glass_card.dart';
import '../../../core/utils/asset_resolver.dart';
import '../../../core/utils/dialog_utils.dart';

class StaffMenuPage extends ConsumerStatefulWidget {
  const StaffMenuPage({super.key});

  @override
  ConsumerState<StaffMenuPage> createState() => _StaffMenuPageState();
}

class _StaffMenuPageState extends ConsumerState<StaffMenuPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(allProductsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Menu Management')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 64, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  const Text('No products yet. Tap + to add one.'),
                ],
              ),
            );
          }

          final rawCategories = products
              .map((p) => p.category.trim())
              .where((c) => c.isNotEmpty)
              .toSet()
              .toList();
          rawCategories.sort();
          final categories = ['All', ...rawCategories];

          var filtered = products.where((p) {
            if (_selectedCategory.toLowerCase() != 'all' &&
                p.category.toLowerCase() !=
                    _selectedCategory.toLowerCase()) {
              return false;
            }
            if (_query.isNotEmpty) {
              final q = _query.toLowerCase();
              return p.name.toLowerCase().contains(q) ||
                  p.category.toLowerCase().contains(q);
            }
            return true;
          }).toList();

          // Group by category
          final grouped = <String, List<Product>>{};
          for (final p in filtered) {
            grouped.putIfAbsent(p.category, () => []).add(p);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 10.0),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search menu by name or category...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                              _query = '';
                            }),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (v) {
                    setState(() {
                      _query = v;
                    });
                  },
                ),
              ),

              // ── Category filter chips ──────────────────────────────────────────
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    final isSelected = _selectedCategory.toLowerCase() ==
                        cat.toLowerCase();
                    final displayName = cat == 'All'
                        ? 'All'
                        : (cat.isNotEmpty
                            ? '${cat[0].toUpperCase()}${cat.substring(1)}'
                            : cat);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary
                              : cs.surfaceContainerHighest
                                  .withValues(alpha: 0.5),
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
                                    color:
                                        cs.primary.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              color:
                                  isSelected ? cs.onPrimary : cs.onSurface,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.coffee_outlined,
                                size: 56,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No menu items found in "$_selectedCategory".',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (_selectedCategory != 'All' || _query.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _selectedCategory = 'All';
                                      _searchCtrl.clear();
                                      _query = '';
                                    });
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Reset Filters'),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        children: [
                    for (final category in grouped.keys) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
                        child: Text(
                          category.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                        ),
                      ).animate().fadeIn(delay: 50.ms).slideX(begin: -0.05, end: 0),
                      ...grouped[category]!.asMap().entries.map((entry) {
                        final index = entry.key;
                        final product = entry.value;
                        return _ProductTile(
                          product: product,
                          onEdit: () => _showProductDialog(context, ref, product),
                          onDelete: () => _confirmDelete(context, ref, product),
                          onToggle: () => ref
                              .read(productCrudProvider.notifier)
                              .toggleAvailability(product),
                          onToggleFeatured: () {
                            final updated = product.copyWith(isFeatured: !product.isFeatured);
                            ref.read(productCrudProvider.notifier).updateProduct(updated);
                          },
                        ).animate().fadeIn(delay: (100 + index * 50).ms).slideX(begin: 0.05, end: 0);
                      }),
                    ],
                  ],
                ).animate().fadeIn(duration: 300.ms),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Product product) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete Product?',
      message: '"${product.name}" will be permanently removed from the menu.',
      isDestructive: true,
      confirmText: 'Delete',
    );
    if (confirmed) {
      await ref.read(productCrudProvider.notifier).deleteProduct(product.id);
      if (context.mounted) {
        AppDialogs.showNotice(context, '${product.name} removed successfully.');
      }
    }
  }

  void _showProductDialog(BuildContext context, WidgetRef ref, Product? existing) {
    showDialog(
      context: context,
      builder: (ctx) => _ProductFormDialog(existing: existing, ref: ref),
    );
  }
}

// ── Drink image asset mapping ────────────────────────────────────────────────

// ── Product tile ──────────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onToggleFeatured,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  final VoidCallback onToggleFeatured;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final assetPath = resolveProductAssetImage(product.name);

    Widget leading;
    if (assetPath != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: ColorFiltered(
          colorFilter: product.isAvailable
              ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
              : ColorFilter.mode(Colors.grey.withValues(alpha: 0.6), BlendMode.saturation),
          child: Image.asset(
            assetPath,
            width: 52,
            height: 52,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _iconAvatar(cs),
          ),
        ),
      );
    } else if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          product.imageUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconAvatar(cs),
        ),
      );
    } else {
      leading = _iconAvatar(cs);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedGlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: leading,
          title: Text(
            product.name,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: product.isAvailable ? Colors.black87 : cs.onSurfaceVariant,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '₱${product.price.toStringAsFixed(2)}  •  '
                '${product.stock != null ? "Stock: ${product.stock}" : "Unlimited"}',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    product.isAvailable ? 'Available ' : 'Unavailable ',
                    style: TextStyle(
                      fontSize: 12,
                      color: product.isAvailable ? Colors.green : Colors.grey,
                    ),
                  ),
                  Switch.adaptive(
                    value: product.isAvailable,
                    onChanged: (_) => onToggle(),
                  ),
                  IconButton(
                    icon: Icon(
                      product.isFeatured ? Icons.star : Icons.star_border,
                      color: product.isFeatured ? Colors.orange : cs.onSurface,
                    ),
                    onPressed: onToggleFeatured,
                    tooltip: 'Toggle Featured',
                  ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'edit') onEdit();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconAvatar(ColorScheme cs) => CircleAvatar(
        backgroundColor: product.isAvailable
            ? cs.primaryContainer
            : cs.surfaceContainerHighest,
        child: Icon(
          Icons.local_cafe_outlined,
          color: product.isAvailable ? cs.primary : cs.onSurfaceVariant,
        ),
      );
}

// ── Add/Edit product dialog ───────────────────────────────────────────────────

class _ProductFormDialog extends StatefulWidget {
  const _ProductFormDialog({this.existing, required this.ref});

  final Product? existing;
  final WidgetRef ref;

  @override
  State<_ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<_ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _category;
  late final TextEditingController _stock;
  late final TextEditingController _imageUrl;
  late bool _isAvailable;
  late bool _isFeatured;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _name = TextEditingController(text: p?.name ?? '');
    _price = TextEditingController(text: p != null ? p.price.toStringAsFixed(2) : '');
    _category = TextEditingController(text: p?.category ?? '');
    _stock = TextEditingController(text: p?.stock?.toString() ?? '');
    _imageUrl = TextEditingController(text: p?.imageUrl ?? '');
    _isAvailable = p?.isAvailable ?? true;
    _isFeatured = p?.isFeatured ?? false;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _category.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit Product' : 'New Product'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field(_name, 'Name', required: true),
                const SizedBox(height: 12),
                _field(_price, 'Price (₱)',
                    required: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]),
                const SizedBox(height: 12),
                _field(_category, 'Category', required: true, hint: 'e.g. Coffee, Food, Drinks'),
                const SizedBox(height: 12),
                _field(_stock, 'Stock (leave blank = unlimited)',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                const SizedBox(height: 12),
                _field(_imageUrl, 'Image URL (optional)'),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  title: const Text('Available on menu'),
                  value: _isAvailable,
                  onChanged: (v) => setState(() => _isAvailable = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile.adaptive(
                  title: const Text('Featured on landing page'),
                  value: _isFeatured,
                  onChanged: (v) => setState(() => _isFeatured = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: Text(isEdit ? 'Save' : 'Add')),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) =>
      TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: required ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null : null,
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isNew = widget.existing == null;
    final actionName = isNew ? 'Add' : 'Save Changes';

    final confirm = await AppDialogs.confirm(
      context,
      title: '$actionName Product?',
      message: 'Are you sure you want to ${isNew ? 'add this new' : 'save changes to this'} product?',
      confirmText: actionName,
    );
    if (!confirm) return;

    final product = Product(
      id: widget.existing?.id ?? '',
      name: _name.text.trim(),
      price: double.tryParse(_price.text.trim()) ?? 0,
      category: _category.text.trim(),
      isAvailable: _isAvailable,
      isFeatured: _isFeatured,
      stock: _stock.text.trim().isEmpty ? null : int.tryParse(_stock.text.trim()),
      imageUrl: _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
      itemId: widget.existing?.itemId,
      cost: widget.existing?.cost,
      servingSize: widget.existing?.servingSize ?? '16 oz',
      recipe: widget.existing?.recipe ?? const [],
      recipeSmall: widget.existing?.recipeSmall ?? const [],
    );

    final notifier = widget.ref.read(productCrudProvider.notifier);
    if (isNew) {
      await notifier.addProduct(product);
    } else {
      await notifier.updateProduct(product);
    }

    final state = widget.ref.read(productCrudProvider);
    if (state.hasError) {
      if (mounted) {
        AppDialogs.showNotice(context, 'Error: ${state.error}', isError: true);
      }
      return; 
    }

    if (mounted) {
      AppDialogs.showNotice(context, 'Product ${isNew ? 'added' : 'updated'} successfully.');
      Navigator.pop(context);
    }
  }
}
