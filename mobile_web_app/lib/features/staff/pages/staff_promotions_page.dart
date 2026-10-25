import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/models/promotion.dart';
import '../../../core/providers/staff_providers.dart';
import '../../../core/utils/dialog_utils.dart';
import '../../../core/widgets/animated_glass_card.dart';

class StaffPromotionsPage extends ConsumerStatefulWidget {
  const StaffPromotionsPage({super.key});

  @override
  ConsumerState<StaffPromotionsPage> createState() => _StaffPromotionsPageState();
}

class _StaffPromotionsPageState extends ConsumerState<StaffPromotionsPage> {
  String _filter = 'ALL'; // ALL, SEEN, HIDDEN, INACTIVE

  @override
  Widget build(BuildContext context) {
    final promosAsync = ref.watch(allPromotionsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Promotions & Discounts'),
      ),
      body: promosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (promos) {
          final seenCount = promos.where((p) => p.isActive && p.isVisible).length;
          final hiddenCount = promos.where((p) => p.isActive && !p.isVisible).length;
          final inactiveCount = promos.where((p) => !p.isActive).length;

          final filteredPromos = promos.where((p) {
            if (_filter == 'SEEN') return p.isActive && p.isVisible;
            if (_filter == 'HIDDEN') return p.isActive && !p.isVisible;
            if (_filter == 'INACTIVE') return !p.isActive;
            return true;
          }).toList();

          return Column(
            children: [
              // ── Filter Bar ───────────────────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _buildFilterChip('ALL', 'All (${promos.length})'),
                    const SizedBox(width: 8),
                    _buildFilterChip('SEEN', 'Seen on Dashboard ($seenCount)', icon: Icons.visibility_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('HIDDEN', 'Hidden ($hiddenCount)', icon: Icons.visibility_off_rounded),
                    const SizedBox(width: 8),
                    _buildFilterChip('INACTIVE', 'Inactive ($inactiveCount)', icon: Icons.pause_circle_outline_rounded),
                  ],
                ),
              ),

              // ── Promotions List ───────────────────────────────────────
              Expanded(
                child: filteredPromos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.discount_outlined, size: 56, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                              _filter == 'ALL'
                                  ? 'No promotions created yet.'
                                  : 'No promotions matching $_filter filter.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredPromos.length,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemBuilder: (context, index) {
                          final promo = filteredPromos[index];
                          final isSeen = promo.isActive && promo.isVisible;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AnimatedGlassCard(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Row: Code Badge & Discount Badge + Actions
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: cs.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.confirmation_number_outlined, size: 16, color: cs.primary),
                                            const SizedBox(width: 6),
                                            Text(
                                              promo.code,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                letterSpacing: 0.5,
                                                color: cs.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: cs.secondaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          promo.type == DiscountType.percentage
                                              ? '${promo.value.toInt()}% OFF'
                                              : '₱${promo.value.toStringAsFixed(0)} OFF',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                            color: cs.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        tooltip: 'Edit Promotion',
                                        onPressed: () => _showEditPromoDialog(context, promo),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        tooltip: 'Delete Promotion',
                                        onPressed: () => _confirmDelete(context, promo),
                                      ),
                                    ],
                                  ),

                                  if (promo.description.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      promo.description,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ],

                                  // Details Section: What the promo has
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: cs.outlineVariant.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.info_outline_rounded, size: 14, color: cs.primary),
                                            const SizedBox(width: 5),
                                            Text(
                                              'Promo Details & What\'s Included:',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: cs.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          promo.details.isNotEmpty
                                              ? promo.details
                                              : (promo.description.isNotEmpty
                                                  ? promo.description
                                                  : 'No specific terms or restrictions set.'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: cs.onSurfaceVariant,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),
                                  const Divider(height: 1),
                                  const SizedBox(height: 8),

                                  // Controls Row: Active toggle and Dashboard Visibility toggle
                                  Row(
                                    children: [
                                      // Active Toggle
                                      Expanded(
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () => ref.read(promotionCrudProvider.notifier).toggleActive(promo),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  promo.isActive ? Icons.check_circle_rounded : Icons.cancel_outlined,
                                                  size: 16,
                                                  color: promo.isActive ? Colors.green : Colors.grey,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  promo.isActive ? 'Active' : 'Inactive',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: promo.isActive ? Colors.green : Colors.grey,
                                                  ),
                                                ),
                                                const Spacer(),
                                                Transform.scale(
                                                  scale: 0.75,
                                                  child: Switch.adaptive(
                                                    value: promo.isActive,
                                                    activeTrackColor: Colors.green,
                                                    onChanged: (_) {
                                                      ref.read(promotionCrudProvider.notifier).toggleActive(promo);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),

                                      Container(
                                        height: 24,
                                        width: 1,
                                        color: cs.outlineVariant.withValues(alpha: 0.5),
                                        margin: const EdgeInsets.symmetric(horizontal: 10),
                                      ),

                                      // Seen / Hidden on Customer Dashboard Toggle
                                      Expanded(
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(8),
                                          onTap: () => ref.read(promotionCrudProvider.notifier).toggleVisibility(promo),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  promo.isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                                  size: 16,
                                                  color: isSeen ? cs.primary : (promo.isVisible ? Colors.orange : Colors.grey),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    promo.isVisible ? 'Seen on Dash' : 'Hidden',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: promo.isVisible ? cs.primary : Colors.grey,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                Transform.scale(
                                                  scale: 0.75,
                                                  child: Switch.adaptive(
                                                    value: promo.isVisible,
                                                    activeTrackColor: cs.primary,
                                                    onChanged: (_) {
                                                      ref.read(promotionCrudProvider.notifier).toggleVisibility(promo);
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(delay: (25 * index).ms).slideX(begin: 0.04, end: 0),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPromoDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('New Promo'),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, {IconData? icon}) {
    final isSelected = _filter == value;
    final cs = Theme.of(context).colorScheme;

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: icon != null
          ? Icon(icon, size: 14, color: isSelected ? cs.onPrimary : cs.onSurfaceVariant)
          : null,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
      ),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      selectedColor: cs.primary,
      onSelected: (val) {
        if (val) setState(() => _filter = value);
      },
    );
  }

  void _confirmDelete(BuildContext context, Promotion promo) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete Promotion?',
      message: 'Are you sure you want to delete promo code "${promo.code}"?',
      isDestructive: true,
      confirmText: 'Delete',
    );
    if (confirmed) {
      await ref.read(promotionCrudProvider.notifier).deletePromotion(promo.id);
      if (context.mounted) {
        AppDialogs.showNotice(context, 'Promotion ${promo.code} deleted.');
      }
    }
  }

  void _showAddPromoDialog(BuildContext context) {
    final codeCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final detailsCtrl = TextEditingController();
    final valueCtrl = TextEditingController();
    DiscountType selectedType = DiscountType.percentage;
    bool isVisible = true;
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.add_circle_outline, color: Colors.brown),
                  SizedBox(width: 8),
                  Text('Add Promotion'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Promo Code *',
                        hintText: 'e.g. SUMMER20',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Short Description *',
                        hintText: 'e.g. 20% off all summer coolers',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Promo Details / What\'s Included',
                        hintText: 'e.g. Valid for all Classic and Frappe drinks. Min order ₱150. Valid for dine-in and pickup.',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.list_alt_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DiscountType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Discount Type',
                        prefixIcon: Icon(Icons.tune_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: DiscountType.percentage,
                          child: Text('Percentage (% Off)'),
                        ),
                        DropdownMenuItem(
                          value: DiscountType.fixed,
                          child: Text('Fixed Amount (₱ Off)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valueCtrl,
                      decoration: InputDecoration(
                        labelText: selectedType == DiscountType.percentage
                            ? 'Discount Percentage (e.g. 20 for 20%)'
                            : 'Discount Amount (e.g. 50 for ₱50)',
                        prefixIcon: Icon(
                          selectedType == DiscountType.percentage ? Icons.percent : Icons.attach_money,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    // Visibility switch
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: isVisible ? Colors.green : Colors.grey,
                      ),
                      title: const Text('Seen on Customer Dashboard', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Show promo banner & details to customers', style: TextStyle(fontSize: 11)),
                      value: isVisible,
                      onChanged: (val) => setState(() => isVisible = val),
                    ),
                    // Active switch
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        isActive ? Icons.check_circle_rounded : Icons.cancel_outlined,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                      title: const Text('Active for Checkout', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Customers can apply this code during checkout', style: TextStyle(fontSize: 11)),
                      value: isActive,
                      onChanged: (val) => setState(() => isActive = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final code = codeCtrl.text.trim().toUpperCase();
                    final desc = descCtrl.text.trim();
                    final details = detailsCtrl.text.trim();
                    final val = double.tryParse(valueCtrl.text.trim()) ?? 0.0;
                    if (code.isEmpty) {
                      AppDialogs.showNotice(context, 'Please enter a promo code.');
                      return;
                    }
                    if (val <= 0) {
                      AppDialogs.showNotice(context, 'Please enter a valid discount value.');
                      return;
                    }

                    final confirmed = await AppDialogs.confirm(
                      context,
                      title: 'Add Promotion',
                      message: 'Add promo code "$code" (${selectedType == DiscountType.percentage ? '$val%' : '₱$val'} off)?',
                      confirmText: 'Add Promo',
                    );
                    if (!confirmed) return;

                    await ref.read(promotionCrudProvider.notifier).addPromotion(
                          Promotion(
                            id: '',
                            code: code,
                            description: desc.isNotEmpty ? desc : '$code Special Promo',
                            details: details,
                            type: selectedType,
                            value: val,
                            isActive: isActive,
                            isVisible: isVisible,
                          ),
                        );
                    if (context.mounted) {
                      AppDialogs.showNotice(context, 'Promotion $code added successfully.');
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Promo'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditPromoDialog(BuildContext context, Promotion promo) {
    final codeCtrl = TextEditingController(text: promo.code);
    final descCtrl = TextEditingController(text: promo.description);
    final detailsCtrl = TextEditingController(text: promo.details);
    final valueCtrl = TextEditingController(text: promo.value.toString());
    DiscountType selectedType = promo.type;
    bool isVisible = promo.isVisible;
    bool isActive = promo.isActive;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Colors.brown),
                  const SizedBox(width: 8),
                  Text('Edit Promo ${promo.code}'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Promo Code *',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Short Description',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: detailsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Promo Details / What\'s Included',
                        hintText: 'e.g. Valid for all Classic and Frappe drinks. Min order ₱150.',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(bottom: 40),
                          child: Icon(Icons.list_alt_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<DiscountType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Discount Type',
                        prefixIcon: Icon(Icons.tune_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: DiscountType.percentage,
                          child: Text('Percentage (% Off)'),
                        ),
                        DropdownMenuItem(
                          value: DiscountType.fixed,
                          child: Text('Fixed Amount (₱ Off)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => selectedType = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: valueCtrl,
                      decoration: InputDecoration(
                        labelText: selectedType == DiscountType.percentage
                            ? 'Discount Percentage (%)'
                            : 'Discount Amount (₱)',
                        prefixIcon: Icon(
                          selectedType == DiscountType.percentage ? Icons.percent : Icons.attach_money,
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    // Visibility switch
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        color: isVisible ? Colors.green : Colors.grey,
                      ),
                      title: const Text('Seen on Customer Dashboard', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Show promo card on customer dashboard', style: TextStyle(fontSize: 11)),
                      value: isVisible,
                      onChanged: (val) => setState(() => isVisible = val),
                    ),
                    // Active switch
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        isActive ? Icons.check_circle_rounded : Icons.cancel_outlined,
                        color: isActive ? Colors.green : Colors.grey,
                      ),
                      title: const Text('Active for Checkout', style: TextStyle(fontSize: 14)),
                      subtitle: const Text('Allow code at checkout', style: TextStyle(fontSize: 11)),
                      value: isActive,
                      onChanged: (val) => setState(() => isActive = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final code = codeCtrl.text.trim().toUpperCase();
                    final desc = descCtrl.text.trim();
                    final details = detailsCtrl.text.trim();
                    final val = double.tryParse(valueCtrl.text.trim()) ?? 0.0;
                    if (code.isEmpty || val <= 0) {
                      AppDialogs.showNotice(context, 'Please enter a valid code and value.');
                      return;
                    }

                    final updated = promo.copyWith(
                      code: code,
                      description: desc,
                      details: details,
                      type: selectedType,
                      value: val,
                      isActive: isActive,
                      isVisible: isVisible,
                    );

                    await ref.read(promotionCrudProvider.notifier).updatePromotion(updated);
                    if (context.mounted) {
                      AppDialogs.showNotice(context, 'Promo $code updated.');
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
