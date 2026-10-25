import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/analytics/analytics_engine.dart';
import '../../../core/providers/analytics_providers.dart';
import '../../../core/utils/export_csv_util.dart';
import '../widgets/analytics_charts.dart';

class StaffAnalyticsPage extends ConsumerWidget {
  const StaffAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(analyticsReportProvider);
    final selection = ref.watch(analyticsSelectionProvider);
    final liveSync = ref.watch(liveFirebaseSyncStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Owner Analytics & Operations Flow',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Live Firebase: ${liveSync.ordersCount} orders synced',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    color: Colors.greenAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Refresh Live Firebase Data',
            onPressed: () {
              refreshLiveFirebaseAnalytics(ref);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚡ Syncing latest real-time orders from Firebase Firestore...'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AnalyticsPreset>(
                value: selection.preset,
                items: AnalyticsPreset.values.map((preset) {
                  return DropdownMenuItem(
                    value: preset,
                    child: Text(preset.label),
                  );
                }).toList(),
                onChanged: (val) async {
                  if (val != null) {
                    if (val == AnalyticsPreset.custom) {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2023, 1, 1),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: selection.customStart != null &&
                                selection.customEnd != null
                            ? DateTimeRange(
                                start: selection.customStart!,
                                end: selection.customEnd!,
                              )
                            : DateTimeRange(
                                start: DateTime.now()
                                    .subtract(const Duration(days: 30)),
                                end: DateTime.now(),
                              ),
                      );
                      if (picked != null) {
                        ref.read(analyticsSelectionProvider.notifier).state =
                            AnalyticsSelection(
                          AnalyticsPreset.custom,
                          customStart: picked.start,
                          customEnd: picked.end,
                        );
                      }
                    } else {
                      ref.read(analyticsSelectionProvider.notifier).state =
                          AnalyticsSelection(val);
                    }
                  }
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Reports (Exact Auto-Spaced CSV)',
            onPressed: () {
              final r = reportAsync.valueOrNull;
              if (r != null) {
                _showExportDialog(context, r);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report not ready yet')),
                );
              }
            },
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Connecting to live Firebase Firestore database...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 6),
              Text(
                'Streaming orders, menu items, reviews, and stock levels in real time',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        error: (e, st) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Error loading Firebase data: $e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => refreshLiveFirebaseAnalytics(ref),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Connection'),
                ),
              ],
            ),
          ),
        ),
        data: (report) {
          return DefaultTabController(
            length: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LiveFirebaseSyncHeader(
                  sync: liveSync,
                  selection: selection,
                  report: report,
                  onRefresh: () {
                    refreshLiveFirebaseAnalytics(ref);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⚡ Syncing latest real-time orders from Firebase Firestore...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                _KpiSummaryBanner(report: report),
                const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(
                      icon: Icon(Icons.dashboard_outlined, size: 18),
                      text: 'All (Full Flow)',
                    ),
                    Tab(
                      icon: Icon(Icons.bar_chart_outlined, size: 18),
                      text: 'Descriptive',
                    ),
                    Tab(
                      icon: Icon(Icons.psychology_outlined, size: 18),
                      text: 'Predictive & ML',
                    ),
                    Tab(
                      icon: Icon(Icons.lightbulb_outline, size: 18),
                      text: 'Prescriptive',
                    ),
                    Tab(
                      icon: Icon(Icons.people_outline, size: 18),
                      text: 'Customer Flow & RFM',
                    ),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _AllFullFlowView(report: report),
                      _DescriptiveView(report: report.descriptive),
                      _PredictiveView(report: report.predictive),
                      _PrescriptiveView(report: report.prescriptive),
                      _CustomerFlowView(report: report.prescriptive),
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

  void _showExportDialog(BuildContext context, AnalyticsReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Analytics Reports'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download_done, color: Colors.teal),
                title: const Text('Full Flow Operations (CSV)'),
                subtitle: const Text('All descriptive, predictive, prescriptive, & customer flow'),
                onTap: () async {
                  Navigator.pop(context);
                  await ExportCsvUtil.exportAnalytics(
                      report, AnalyticsExportSection.full);
                },
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart, color: Colors.brown),
                title: const Text('Descriptive Analytics (CSV)'),
                subtitle: const Text('Sales trends, products, peak hours, categories'),
                onTap: () async {
                  Navigator.pop(context);
                  await ExportCsvUtil.exportAnalytics(
                      report, AnalyticsExportSection.descriptive);
                },
              ),
              ListTile(
                leading: const Icon(Icons.psychology, color: Colors.deepPurple),
                title: const Text('Predictive & ML Forecasts (CSV)'),
                subtitle: const Text('ML scorecard, cash flow, queue flow, category demand'),
                onTap: () async {
                  Navigator.pop(context);
                  await ExportCsvUtil.exportAnalytics(
                      report, AnalyticsExportSection.predictive);
                },
              ),
              ListTile(
                leading: const Icon(Icons.lightbulb_outline, color: Colors.orange),
                title: const Text('Prescriptive Action Plan (CSV)'),
                subtitle: const Text('Restock plan, menu matrix, promo timing, bundles'),
                onTap: () async {
                  Navigator.pop(context);
                  await ExportCsvUtil.exportAnalytics(
                      report, AnalyticsExportSection.prescriptive);
                },
              ),
              ListTile(
                leading: const Icon(Icons.people_outline, color: Colors.indigo),
                title: const Text('Customer Flow & RFM Segments (CSV)'),
                subtitle: const Text('VIP Champions, loyal patrons, churn risk cohorts'),
                onTap: () async {
                  Navigator.pop(context);
                  await ExportCsvUtil.exportAnalytics(
                      report, AnalyticsExportSection.customerFlow);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Top KPI Overview Banner ──────────────────────────────────────────────────

class _KpiSummaryBanner extends StatelessWidget {
  const _KpiSummaryBanner({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final k = report.descriptive.kpis;
    final p = report.descriptive.previousKpis;
    final revChg = pctChange(k.revenue, p.revenue);
    final ordChg = pctChange(k.orders, p.orders);
    final aovChg = pctChange(k.aov, p.aov);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _KpiBadge(
              label: 'Total Revenue',
              value: formatPeso(k.revenue),
              pct: revChg,
              icon: Icons.payments_outlined,
              accent: kChartPalette[0],
            ),
            const SizedBox(width: 10),
            _KpiBadge(
              label: 'Valid Orders',
              value: '${k.orders}',
              pct: ordChg,
              icon: Icons.receipt_long_outlined,
              accent: kChartPalette[1],
            ),
            const SizedBox(width: 10),
            _KpiBadge(
              label: 'Average Order Value',
              value: formatPeso(k.aov),
              pct: aovChg,
              icon: Icons.shopping_bag_outlined,
              accent: kChartPalette[2],
            ),
            const SizedBox(width: 10),
            _KpiBadge(
              label: 'Items Sold',
              value: '${k.itemsSold} units',
              icon: Icons.coffee_outlined,
              accent: kChartPalette[3],
            ),
            const SizedBox(width: 10),
            _KpiBadge(
              label: 'Customer Retention',
              value: '${report.prescriptive.retentionRate.toStringAsFixed(1)}%',
              caption: '${k.customers} unique patrons',
              icon: Icons.people_alt_outlined,
              accent: kChartPalette[5],
            ),
            const SizedBox(width: 10),
            _KpiBadge(
              label: 'ML Forecast Accuracy',
              value: '${(report.predictive.revenue.model.accuracy * 100).toStringAsFixed(1)}%',
              caption: 'Ensemble Learning',
              icon: Icons.auto_awesome_outlined,
              accent: kForecast,
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiBadge extends StatelessWidget {
  const _KpiBadge({
    required this.label,
    required this.value,
    this.pct,
    this.caption,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final double? pct;
  final String? caption;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPos = (pct ?? 0) >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (pct != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isPos
                            ? kGood.withValues(alpha: 0.15)
                            : kBad.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${isPos ? '+' : ''}${pct!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isPos ? kGood : kBad,
                        ),
                      ),
                    ),
                  ],
                  if (caption != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      caption!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Live Firebase Sync Status Header ─────────────────────────────────────────

class _LiveFirebaseSyncHeader extends StatelessWidget {
  const _LiveFirebaseSyncHeader({
    required this.sync,
    required this.selection,
    required this.report,
    required this.onRefresh,
  });

  final LiveFirebaseSyncStatus sync;
  final AnalyticsSelection selection;
  final AnalyticsReport report;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasOrders = report.descriptive.kpis.orders > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.18),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent,
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  'Live Firebase Database Connected',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Synced ${DateFormat('h:mm:ss a').format(sync.lastSynced)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: onRefresh,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sync, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Refresh Live',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SyncPill(
                  icon: Icons.receipt_long,
                  label: '${sync.ordersCount} Live Orders',
                  tooltip: 'Real-time orders streamed from Firebase Firestore "orders"',
                ),
                const SizedBox(width: 8),
                _SyncPill(
                  icon: Icons.coffee,
                  label: '${sync.productsCount} Menu Drinks',
                  tooltip: 'Active menu items from Firebase Firestore "products"',
                ),
                const SizedBox(width: 8),
                _SyncPill(
                  icon: Icons.star,
                  label: '${sync.feedbackCount} Reviews',
                  tooltip: 'Patron reviews from Firebase Firestore "feedback"',
                ),
                const SizedBox(width: 8),
                _SyncPill(
                  icon: Icons.inventory_2,
                  label: '${sync.ingredientsCount} Stock Items',
                  tooltip: 'Inventory holdings from Firebase Firestore "ingredients"',
                ),
              ],
            ),
          ),
          if (!hasOrders) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No orders found for the "${selection.preset.label}" filter. Switch to "All Time" or place a live order in the cashier terminal to view charts.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
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

class _SyncPill extends StatelessWidget {
  const _SyncPill({
    required this.icon,
    required this.label,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: theme.colorScheme.primary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Plain English Explanation Dialog ─────────────────────────────────────────

void _showPlainEnglishModal(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String explanation,
  required String howToAct,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.school_outlined, color: Colors.teal),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              subtitle,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Divider(height: 24),
            const Text(
              '📖 What this means in plain words:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(explanation, style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),
            const Text(
              '🎯 How to act on this:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(howToAct, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it!'),
        ),
      ],
    ),
  );
}

// ── Executive Café Coach Briefing Card ───────────────────────────────────────

class _CafeCoachBriefingCard extends StatelessWidget {
  const _CafeCoachBriefingCard({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final k = report.descriptive.kpis;
    final pred = report.predictive;
    final presc = report.prescriptive;

    // Find peak rush hour
    var peakHour = 14;
    var peakOrders = 0.0;
    for (var i = 0; i < pred.tomorrowHourly.length; i++) {
      if (pred.tomorrowHourly[i] > peakOrders) {
        peakOrders = pred.tomorrowHourly[i];
        peakHour = i;
      }
    }
    final peakStaff = math.max(1, (peakOrders / 12).ceil());

    // Urgent restock
    final needing = presc.restock.where((r) => r.reorderQty > 0).toList();
    final vipCount = presc.rfmSegments.isNotEmpty ? presc.rfmSegments.first.customerCount : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.secondary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.lightbulb, color: theme.colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Café Coach: Today\'s Friendly Briefing',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Your store\'s live health & action plan in plain English',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _BriefingRow(
            icon: Icons.payments,
            color: kChartPalette[0],
            title: 'Revenue Snapshot',
            description:
                'You\'ve earned ${formatPeso(k.revenue)} across ${k.orders} orders. Patrons spend an average of ${formatPeso(k.aov)} per visit.',
          ),
          const SizedBox(height: 10),
          _BriefingRow(
            icon: Icons.auto_awesome,
            color: kForecast,
            title: 'Tomorrow\'s AI Outlook',
            description:
                'AI predicts around ${formatPeso(pred.revenue.forecastAvg)} tomorrow. Slow day baseline is ${formatPeso(pred.cashFlow.p10Pessimistic)}, while a busy rush could reach ${formatPeso(pred.cashFlow.p90Optimistic)}.',
          ),
          const SizedBox(height: 10),
          _BriefingRow(
            icon: Icons.people,
            color: kChartPalette[3],
            title: 'Counter Rush & Staffing',
            description:
                'Busiest rush expected at ${hourLabel(peakHour)} (~${peakOrders.toStringAsFixed(0)} orders/hr). Schedule $peakStaff barista(s) to keep wait times under 3 minutes.',
          ),
          const SizedBox(height: 10),
          _BriefingRow(
            icon: Icons.inventory_2,
            color: needing.isNotEmpty ? kWarn : kGood,
            title: 'Inventory Priority',
            description: needing.isNotEmpty
                ? '${needing.length} item(s) running low (${needing.take(2).map((r) => r.product.name).join(', ')}). Restock soon to prevent 86ing.'
                : 'All tracked ingredients and drinks are well-stocked for the week!',
          ),
          const SizedBox(height: 10),
          _BriefingRow(
            icon: Icons.workspace_premium,
            color: kChartPalette[5],
            title: 'Loyal Patrons',
            description:
                'You have $vipCount VIP regular customer(s) visiting weekly. Greet them by name and offer a surprise loyalty perk!',
          ),
        ],
      ),
    );
  }
}

class _BriefingRow extends StatelessWidget {
  const _BriefingRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.explanation,
    this.howToAct,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? explanation;
  final String? howToAct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (explanation != null)
            IconButton(
              icon: Icon(Icons.info_outline, color: theme.colorScheme.primary, size: 20),
              tooltip: 'Explain this section in plain English',
              onPressed: () {
                _showPlainEnglishModal(
                  context,
                  title: title,
                  subtitle: subtitle,
                  explanation: explanation!,
                  howToAct: howToAct ?? 'Use these live insights to run your store efficiently.',
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── All (Full Flow) View ─────────────────────────────────────────────────────

class _AllFullFlowView extends StatelessWidget {
  const _AllFullFlowView({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CafeCoachBriefingCard(report: report),
        _SectionHeader(
          title: '1. Descriptive Operations Flow',
          subtitle: 'What happened: Historical sales, popular drinks, and busy store hours',
          icon: Icons.bar_chart,
          explanation:
              'This section shows your actual past store performance based on every order recorded in Firebase. Review what drinks sell most, which payment methods customers prefer, and when peak foot traffic occurs.',
          howToAct:
              'Ensure baristas prep the most popular drinks ahead of time and keep enough small change or digital payment QR codes ready during peak hours.',
        ),
        _DescriptiveView(report: report.descriptive, isNested: true),
        const SizedBox(height: 32),
        _SectionHeader(
          title: '2. Predictive & Machine Learning Forecasting Flow',
          subtitle: 'What will happen: AI sales predictions, expected rush hours, and cash flow',
          icon: Icons.psychology,
          explanation:
              'Our AI uses 3 machine learning algorithms to forecast future sales, customer queue times, and forward cash flow with ${(report.predictive.revenue.model.accuracy * 100).toStringAsFixed(1)}% accuracy. It accounts for weekend spikes and recent store momentum.',
          howToAct:
              'Use the P10/P90 cash flow bands to plan your weekly inventory budget, and check the hourly queue flow to schedule extra staff for upcoming rush periods.',
        ),
        _PredictiveView(report: report.predictive, isNested: true),
        const SizedBox(height: 32),
        _SectionHeader(
          title: '3. Prescriptive Strategy & Action Recommendations',
          subtitle: 'What to do next: Automated restock list, optimal promo days, and menu advice',
          icon: Icons.lightbulb_outline,
          explanation:
              'This automated coach turns data into direct action. It calculates exact reorder quantities before stock runs out, finds the best slow days to run promotions, and highlights your highest-profit drinks.',
          howToAct:
              'Order ingredients marked in RED (restock today), launch discounts on your slowest weekday, and train staff to recommend "Hidden Gem" menu items.',
        ),
        _PrescriptiveView(report: report.prescriptive, isNested: true),
        const SizedBox(height: 32),
        _SectionHeader(
          title: '4. Customer Flow & RFM Loyalty Segments',
          subtitle: 'Who your customers are: Recognize regular patrons and prevent churn',
          icon: Icons.people_outline,
          explanation:
              'Customer RFM groups your patrons into 5 clear lifecycle cohorts: Champions (VIPs), Loyal Patrons, Promising Big Spenders, At-Risk Churn, and Inactive visitors.',
          howToAct:
              'Reward VIPs with personalized perks to maintain loyalty, and send special discounts to At-Risk customers before they stop visiting.',
        ),
        _CustomerFlowView(report: report.prescriptive, isNested: true),
      ],
    );
  }
}

// ── Descriptive View ─────────────────────────────────────────────────────────

class _DescriptiveView extends StatelessWidget {
  final DescriptiveReport report;
  final bool isNested;
  const _DescriptiveView({required this.report, this.isNested = false});

  @override
  Widget build(BuildContext context) {
    final labels = report.buckets.map((b) => b.label).toList();
    final tooltipLabels = report.buckets.map((b) => b.fullLabel).toList();
    final theme = Theme.of(context);
    final children = [
      if (!isNested) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(Icons.insights, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store Historical Sales Guide',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'All numbers below reflect verified, completed orders streamed live from your Firebase database. Use this to review customer drink preferences, peak shopping times, and revenue growth.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      AnalyticsChartCard(
        index: 'D1',
        title: 'Revenue Trend',
        subtitle: 'Total valid order revenue over time',
        headline: formatPeso(report.kpis.revenue),
        insights: [
          if (report.previousKpis.revenue > 0)
            'Revenue is ${((report.kpis.revenue - report.previousKpis.revenue) / report.previousKpis.revenue * 100).toStringAsFixed(1)}% vs previous period',
        ],
        child: TrendLineChart(
          labels: labels,
          tooltipLabels: tooltipLabels,
          series: [
            LineSeries('Revenue', report.revenueTrend, kChartPalette[0]),
          ],
          axisFmt: formatPesoCompact,
          tooltipFmt: formatPeso,
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'D2',
        title: 'Order Volume',
        subtitle: 'Number of completed/valid orders',
        headline: report.kpis.orders.toString(),
        child: ValueBarChart(
          labels: labels,
          tooltipLabels: tooltipLabels,
          series: [
            BarSeries('Orders',
                report.orderTrend.map((e) => e.toDouble()).toList(), kChartPalette[1]),
          ],
          axisFmt: (v) => v.toInt().toString(),
          tooltipFmt: (v) => v.toInt().toString(),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'D3',
        title: 'Average Order Value (AOV)',
        subtitle: 'Revenue divided by valid orders',
        headline: formatPeso(report.kpis.aov),
        child: TrendLineChart(
          labels: labels,
          tooltipLabels: tooltipLabels,
          series: [
            LineSeries('AOV', report.aovTrend, kChartPalette[2]),
          ],
          axisFmt: formatPesoCompact,
          tooltipFmt: formatPeso,
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'D4',
        title: 'Top-Selling Products',
        subtitle: 'Best performing items by quantity',
        height: null,
        child: HBarChart(
          items: report.topProducts
              .map((p) => HBarItem(
                    p.name,
                    p.qty.toDouble(),
                    '${p.qty} units',
                    caption: 'Rev: ${formatPeso(p.revenue)}',
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'D5',
        title: 'Revenue by Category',
        subtitle: 'Share of total revenue by product category',
        child: DonutChart(
          slices: report.categoryRevenue
              .map((c) => DonutSlice(
                    c.label,
                    c.value,
                    kChartPalette[report.categoryRevenue.indexOf(c) %
                        kChartPalette.length],
                    display: formatPesoCompact(c.value),
                  ))
              .toList(),
          centerTitle: 'Total',
          centerValue: formatPesoCompact(
              report.categoryRevenue.fold(0, (a, b) => a + b.value)),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'D6',
        title: 'Order Status',
        subtitle: 'Breakdown of orders by their current status',
        child: DonutChart(
          slices: report.statusCounts.entries
              .map((e) => DonutSlice(
                    e.key.name,
                    e.value.toDouble(),
                    kChartPalette[e.key.index % kChartPalette.length],
                  ))
              .toList(),
          centerTitle: 'Total',
          centerValue: report.statusCounts.values
              .fold<int>(0, (a, b) => a + b)
              .toString(),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'D7',
        title: 'Peak Hours',
        subtitle: 'Traffic distributed by hour of day',
        child: ValueBarChart(
          labels: List.generate(24, (i) => i % 3 == 0 ? hourLabel(i) : ''),
          tooltipLabels: List.generate(24, hourLabel),
          series: [
            BarSeries('Orders',
                report.hourlyOrders.map((e) => e.toDouble()).toList(), kChartPalette[3]),
          ],
          axisFmt: (v) => v.toInt().toString(),
          tooltipFmt: (v) => v.toInt().toString(),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'D8',
        title: 'Sales by Day of Week',
        subtitle: 'Total revenue grouped by weekday',
        child: ValueBarChart(
          labels: kWeekdayShort,
          tooltipLabels: kWeekdayLong,
          series: [
            BarSeries('Revenue', report.weekdayRevenue, kChartPalette[4]),
          ],
          axisFmt: formatPesoCompact,
          tooltipFmt: formatPeso,
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'D9',
        title: 'Order Type',
        subtitle: 'Dine-in vs Take-out revenue',
        child: DonutChart(
          slices: report.orderTypeRevenue.entries
              .map((e) => DonutSlice(
                    e.key.name,
                    e.value,
                    kChartPalette[e.key.index % kChartPalette.length],
                    display: formatPesoCompact(e.value),
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'D10',
        title: 'Customer Ratings',
        subtitle: 'Feedback distribution (1 to 5 stars)',
        headline: report.avgRating > 0
            ? '${report.avgRating.toStringAsFixed(1)} ★'
            : null,
        child: ValueBarChart(
          labels: const ['1★', '2★', '3★', '4★', '5★'],
          series: [
            BarSeries(
                'Reviews',
                report.ratingCounts.map((e) => e.toDouble()).toList(),
                kChartPalette[5]),
          ],
          axisFmt: (v) => v.toInt().toString(),
          tooltipFmt: (v) => v.toInt().toString(),
        ),
      ),
    ];

    if (isNested) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

// ── Predictive View ──────────────────────────────────────────────────────────

class _PredictiveView extends StatelessWidget {
  final PredictiveReport report;
  final bool isNested;
  const _PredictiveView({required this.report, this.isNested = false});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final histLen = report.revenue.history.length;
    // Show up to the last 14 days of actual history leading directly into the 14 days
    // of forward forecast to give clean context without squishing the chart.
    final showHistCount = math.min(histLen, 14);
    final histOffset = histLen - showHistCount;

    final dispHistDates = report.revenue.historyDates.sublist(histOffset);
    final dispRevHist = report.revenue.history.sublist(histOffset);
    final dispOrderHist = report.orders.history.sublist(histOffset);

    final pDateLabels = [
      ...dispHistDates.map(dateFormat.format),
      ...report.revenue.forecastDates.map(dateFormat.format),
    ];
    final pDateFullLabels = [
      ...dispHistDates.map((d) => DateFormat('EEE, MMM d').format(d)),
      ...report.revenue.forecastDates.map((d) => DateFormat('EEE, MMM d').format(d)),
    ];

    // rHist spans only the actual historical points
    final rHist = [
      ...dispRevHist,
      ...List<double?>.filled(report.revenue.forecast.length, null),
    ];

    // Anchor forecast line and confidence bands to the last actual point to eliminate line breaks!
    final lastRevVal = dispRevHist.isNotEmpty ? dispRevHist.last : (report.revenue.forecast.isNotEmpty ? report.revenue.forecast.first : 0.0);
    final rFore = [
      ...List<double?>.filled(math.max(0, dispRevHist.length - 1), null),
      if (dispRevHist.isNotEmpty) lastRevVal,
      ...report.revenue.forecast,
    ];
    final rLow = [
      ...List<double?>.filled(math.max(0, dispRevHist.length - 1), null),
      if (dispRevHist.isNotEmpty) lastRevVal,
      ...report.revenue.p10Forecast,
    ];
    final rHigh = [
      ...List<double?>.filled(math.max(0, dispRevHist.length - 1), null),
      if (dispRevHist.isNotEmpty) lastRevVal,
      ...report.revenue.p90Forecast,
    ];

    // oHist spans actual order history
    final oHist = [
      ...dispOrderHist,
      ...List<double?>.filled(report.orders.forecast.length, null),
    ];

    final lastOrderVal = dispOrderHist.isNotEmpty ? dispOrderHist.last : (report.orders.forecast.isNotEmpty ? report.orders.forecast.first : 0.0);
    final oFore = [
      ...List<double?>.filled(math.max(0, dispOrderHist.length - 1), null),
      if (dispOrderHist.isNotEmpty) lastOrderVal,
      ...report.orders.forecast,
    ];
    final oLow = [
      ...List<double?>.filled(math.max(0, dispOrderHist.length - 1), null),
      if (dispOrderHist.isNotEmpty) lastOrderVal,
      ...report.orders.p10Forecast,
    ];
    final oHigh = [
      ...List<double?>.filled(math.max(0, dispOrderHist.length - 1), null),
      if (dispOrderHist.isNotEmpty) lastOrderVal,
      ...report.orders.p90Forecast,
    ];

    final theme = Theme.of(context);

    String friendlyRole(String name) {
      if (name.contains('Ensemble')) return '⭐ Master AI • Best overall prediction by weighting all 3 models below';
      if (name.contains('Holt-Winters')) return '📈 Weekly Waves • Learns regular weekday vs weekend customer waves';
      if (name.contains('Ridge')) return '🧠 Surge Detector • Fast reaction to recent sales spikes and momentum';
      return '📐 Baseline Guide • Projects overall long-term store growth';
    }

    final children = [
      if (!isNested) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kForecast.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kForecast.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: kForecast, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Sales Forecasting: How It Works in Plain English',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: kForecast,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Our machine learning models study your café\'s past order history, 7-day cyclical patterns (weekends vs weekdays), and recent demand surges to forecast upcoming sales with ${(report.revenue.model.accuracy * 100).toStringAsFixed(1)}% accuracy. We combine 3 smart models so you never under-prepare or over-purchase.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],

      // ML Model Scorecard
      AnalyticsChartCard(
        index: 'ML',
        title: 'Machine Learning Algorithm Scorecard',
        subtitle: 'Ensemble model comparing 3 distinct learning machines',
        headline: '${(report.revenue.model.accuracy * 100).toStringAsFixed(1)}% Accuracy',
        height: null,
        insights: [
          'Ensemble combines Holt-Winters triple smoothing, Ridge AR-7, and de-seasonalized linear trend.',
          'Typical prediction error: only ~${formatPeso(report.revenue.model.residualStd)} per day.',
        ],
        child: Column(
          children: report.modelScores.map((score) {
            final isEnsemble = score.name.contains('Ensemble');
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isEnsemble
                    ? kForecast.withValues(alpha: 0.10)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEnsemble
                      ? kForecast.withValues(alpha: 0.35)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEnsemble
                            ? Icons.auto_awesome
                            : (score.name.contains('Ridge')
                                ? Icons.scatter_plot
                                : Icons.waves),
                        size: 18,
                        color: isEnsemble ? kForecast : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          score.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kGood.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(score.accuracy * 100).toStringAsFixed(1)}% Acc',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: kGood,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    friendlyRole(score.name),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    score.description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetricChip(label: 'Accuracy', value: '${(score.accuracy * 100).toStringAsFixed(1)}%'),
                      _MetricChip(label: 'Error Margin', value: '±${formatPeso(score.rmse)}/day'),
                      _MetricChip(
                        label: 'Influence',
                        value: '${(score.weight * 100).toStringAsFixed(0)}%',
                        accent: isEnsemble ? kForecast : null,
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 16),

      // Cash Flow Projections
      AnalyticsChartCard(
        index: 'CF',
        title: 'Forward Cash Flow Scenarios (${report.cashFlow.days}-Day Run Rate)',
        subtitle: 'Rainy/Slow Day Baseline vs Expected Normal vs Busy Surge Forecast',
        headline: formatPeso(report.cashFlow.expectedTotal),
        height: null,
        insights: [
          'Daily cash run-rate: ${formatPeso(report.cashFlow.dailyRunRate)}/day on average.',
          'Weekend surge multiplier: +${report.cashFlow.weekendSurgePct.toStringAsFixed(1)}% higher store revenue on Saturdays and Sundays.',
        ],
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _ScenarioBox(
                    label: '🌧️ Slow / Rainy Day (P10)',
                    amount: report.cashFlow.p10Pessimistic,
                    color: kWarn,
                    caption: '90% chance to beat this baseline',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ScenarioBox(
                    label: '☕ Expected Normal Day',
                    amount: report.cashFlow.expectedTotal,
                    color: kForecast,
                    caption: 'Most likely normal store sales',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ScenarioBox(
                    label: '☀️ Peak Surge Target (P90)',
                    amount: report.cashFlow.p90Optimistic,
                    color: kGood,
                    caption: 'High potential for busy weekends',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.trending_up, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Store generates ${formatPeso(report.cashFlow.dailyRunRate)} per day on average. Prepare inventory ahead of weekends to capture the +${report.cashFlow.weekendSurgePct.toStringAsFixed(1)}% weekend wave.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Revenue Forecast
      AnalyticsChartCard(
        index: 'P1',
        title: 'Revenue Forecast (Next $kForecastHorizonDays Days)',
        subtitle: 'AI financial forecast • Trained on historical AOV & weekly surge patterns',
        headline: formatPeso(report.revenue.forecastTotal),
        height: 260,
        legend: [
          LegendEntry('Actual Revenue', kChartPalette[0]),
          const LegendEntry('Ensemble Forecast', kForecast, dashed: true),
        ],
        insights: [
          'Forecast avg: ${formatPeso(report.revenue.forecastAvg)}/day',
          'Model accuracy: ${(report.revenue.model.accuracy * 100).toStringAsFixed(1)}%',
          'Pessimistic - Optimistic range: ${formatPeso(report.revenue.p10Total / kForecastHorizonDays)} - ${formatPeso(report.revenue.p90Total / kForecastHorizonDays)}/day',
        ],
        child: TrendLineChart(
          labels: pDateLabels,
          tooltipLabels: pDateFullLabels,
          series: [
            LineSeries('Actual', rHist, kChartPalette[0]),
            LineSeries('Forecast', rFore, kForecast, dashed: true),
          ],
          bandLower: rLow,
          bandUpper: rHigh,
          bandColor: kForecast,
          axisFmt: formatPesoCompact,
          tooltipFmt: formatPeso,
        ),
      ),
      const SizedBox(height: 16),

      // Order Volume Forecast
      AnalyticsChartCard(
        index: 'P2',
        title: 'Order Volume Forecast',
        subtitle: 'AI customer arrival volume • Poisson confidence band & queue capacity',
        headline: '${report.orders.forecastTotal.toStringAsFixed(0)} orders',
        height: 260,
        legend: [
          LegendEntry('Actual Orders', kChartPalette[1]),
          const LegendEntry('Ensemble Forecast', kForecast, dashed: true),
        ],
        insights: [
          'Forecast avg: ${report.orders.forecastAvg.toStringAsFixed(1)} orders/day',
          'Model accuracy: ${(report.orders.model.accuracy * 100).toStringAsFixed(1)}%',
          'Expected daily range: ${(report.orders.p10Total / kForecastHorizonDays).toStringAsFixed(0)} - ${(report.orders.p90Total / kForecastHorizonDays).toStringAsFixed(0)} orders/day',
        ],
        child: TrendLineChart(
          labels: pDateLabels,
          tooltipLabels: pDateFullLabels,
          series: [
            LineSeries('Actual', oHist, kChartPalette[1]),
            LineSeries('Forecast', oFore, kForecast, dashed: true),
          ],
          bandLower: oLow,
          bandUpper: oHigh,
          bandColor: kForecast,
          axisFmt: (v) => v.toInt().toString(),
          tooltipFmt: (v) => '${v.toStringAsFixed(1)} orders',
        ),
      ),
      const SizedBox(height: 16),

      // Customer Queue Flow Simulation
      AnalyticsChartCard(
        index: 'QF',
        title: 'Customer Queue Flow Simulation – Tomorrow',
        subtitle: 'Expected arrival rate vs barista service capacity (12 orders/barista/hr)',
        height: null,
        insights: [
          'Based on historical traffic for ${DateFormat('EEEE').format(report.tomorrow)}s.',
          'Utilization > 85% causes customer line delays. Staffing adjust automatically.',
        ],
        child: Column(
          children: [
            for (final q in report.queueFlowTomorrow.where((q) => q.hour >= 7 && q.hour <= 21))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 55,
                      child: Text(
                        hourLabel(q.hour),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: q.utilization.clamp(0.0, 1.0),
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                            color: q.utilization > 0.90
                                ? kBad
                                : (q.utilization > 0.70 ? kWarn : kGood),
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${q.arrivalRate.toStringAsFixed(1)} orders/hr | Cap: ${q.serviceCapacity}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '~${q.waitMinutes.toStringAsFixed(1)} min',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: q.waitMinutes > 5 ? kBad : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (q.status == 'Congested'
                                ? kBad
                                : (q.status == 'Peak Rush'
                                    ? kWarn
                                    : (q.status == 'Steady' ? kChartPalette[3] : kGood)))
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        q.status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: q.status == 'Congested'
                              ? kBad
                              : (q.status == 'Peak Rush'
                                  ? kWarn
                                  : (q.status == 'Steady' ? kChartPalette[3] : kGood)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // Category Demand Forecast Flow
      AnalyticsChartCard(
        index: 'CD',
        title: 'Category Demand Forecast Flow (Next 7 Days)',
        subtitle: 'Projected unit volume and expected revenue by category',
        height: null,
        child: HBarChart(
          items: report.categoryFlows
              .map((c) => HBarItem(
                    c.category,
                    c.next7Units,
                    '${c.next7Units.toStringAsFixed(0)} units',
                    caption: 'Projected 7-Day Revenue: ${formatPeso(c.next7Revenue)}',
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 16),

      // Product Demand Forecast
      AnalyticsChartCard(
        index: 'P3',
        title: 'Product Demand Forecast (Next 7 Days)',
        subtitle: 'Projected unit sales per individual menu item',
        height: null,
        child: HBarChart(
          items: report.demand
              .map((d) => HBarItem(
                    d.name,
                    d.next7Forecast,
                    '${d.next7Forecast.toStringAsFixed(1)} units',
                    caption:
                        'Last 7 days: ${d.last7Actual} units (Growth: ${d.growth.toStringAsFixed(2)}x)',
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 16),

      // Stock Depletion Forecast
      AnalyticsChartCard(
        index: 'P4',
        title: 'Stock Depletion Forecast',
        subtitle: 'Estimated runout days based on daily consumption rate',
        height: null,
        child: HBarChart(
          items: report.depletion
              .map((d) => HBarItem(
                    d.product.name,
                    (d.daysLeft ?? 999).toDouble(),
                    d.daysLeft == null
                        ? 'No demand'
                        : '${d.daysLeft!.toStringAsFixed(1)} days',
                    caption: d.stockoutDate == null
                        ? null
                        : 'Stock out: ${DateFormat('MMM d').format(d.stockoutDate!)}',
                    color: (d.daysLeft ?? 999) < 3
                        ? kBad
                        : ((d.daysLeft ?? 999) < 7 ? kWarn : kGood),
                  ))
              .toList(),
          maxValue: 14,
        ),
      ),
      const SizedBox(height: 16),

      // Hourly traffic
      AnalyticsChartCard(
        index: 'P5',
        title: 'Expected Hourly Traffic Tomorrow',
        subtitle: DateFormat('EEEE, MMM d').format(report.tomorrow),
        insights: [
          'Based on ${report.tomorrowSamples} past ${DateFormat('EEEE').format(report.tomorrow)}(s).',
        ],
        child: ValueBarChart(
          labels: List.generate(24, (i) => i % 3 == 0 ? hourLabel(i) : ''),
          tooltipLabels: List.generate(24, hourLabel),
          series: [
            BarSeries('Expected Orders', report.tomorrowHourly, kForecast),
          ],
          axisFmt: (v) => v.toInt().toString(),
          tooltipFmt: (v) => v.toStringAsFixed(1),
        ),
      ),
      const SizedBox(height: 16),

      // Monthly Projection
      AnalyticsChartCard(
        index: 'P6',
        title: 'Monthly Revenue Projection',
        subtitle: 'Actual + Projected for current month',
        child: ValueBarChart(
          labels: report.monthly
              .map((m) => DateFormat('MMM').format(m.month))
              .toList(),
          tooltipLabels: report.monthly
              .map((m) => DateFormat('MMMM yyyy').format(m.month))
              .toList(),
          stacked: true,
          series: [
            BarSeries('Actual',
                report.monthly.map((m) => m.actual).toList(), kChartPalette[0]),
            BarSeries(
                'Projected',
                report.monthly.map((m) => m.projected).toList(),
                kForecast.withValues(alpha: 0.5)),
          ],
          axisFmt: formatPesoCompact,
          tooltipFmt: formatPeso,
        ),
      ),

      // AI Anomaly Detection Log
      if (report.anomalies.isNotEmpty) ...[
        const SizedBox(height: 16),
        AnalyticsChartCard(
          index: 'AD',
          title: 'AI Anomaly Detection Event Log',
          subtitle: 'Statistical outliers (>1.96 z-score deviation from model expectation)',
          height: null,
          child: Column(
            children: report.anomalies.map((a) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (a.isSurge ? kGood : kBad).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (a.isSurge ? kGood : kBad).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      a.isSurge ? Icons.trending_up : Icons.trending_down,
                      color: a.isSurge ? kGood : kBad,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('EEEE, MMM d, y').format(a.date),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${a.isSurge ? '+' : ''}${a.deviationPct.toStringAsFixed(1)}% (z=${a.zScore.toStringAsFixed(2)})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: a.isSurge ? kGood : kBad,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            a.explanation,
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Actual: ${formatPeso(a.actual)} vs Expected: ${formatPeso(a.expected)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ];

    if (isNested) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value, this.accent});
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (accent ?? theme.colorScheme.surface).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (accent ?? theme.colorScheme.outlineVariant).withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent ?? theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _ScenarioBox extends StatelessWidget {
  const _ScenarioBox({
    required this.label,
    required this.amount,
    required this.color,
    required this.caption,
  });

  final String label;
  final double amount;
  final Color color;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            formatPeso(amount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 9,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Prescriptive View ────────────────────────────────────────────────────────

class _PrescriptiveView extends StatelessWidget {
  final PrescriptiveReport report;
  final bool isNested;
  const _PrescriptiveView({required this.report, this.isNested = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = [
      if (!isNested) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.checklist, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actionable Store Strategy & Advice',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Turn your live data into profit: Reorder ingredients before they run out, run promotions on slow weekdays, and schedule the right number of baristas for customer rush hours.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      AnalyticsChartCard(
        index: 'R1',
        title: 'Restock Shopping List',
        subtitle:
            'Urgent items and reorder quantities needed for the next $kRestockCoverDays days',
        height: null,
        insights: report.restockInsights,
        child: HBarChart(
          items: report.restock
              .map((r) => HBarItem(
                    r.product.name,
                    r.reorderQty.toDouble(),
                    '${r.reorderQty} units',
                    caption:
                        'Stock: ${r.stock}, Target: ${r.targetLevel}',
                    secondary: r.targetLevel.toDouble(),
                    secondaryColor: Theme.of(context).colorScheme.primary,
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'R2',
        title: 'Best Days for Promotions',
        subtitle: 'Run discounts on slow days, protect full prices on peak days (100 = average)',
        insights: report.promoInsights,
        child: ValueBarChart(
          labels: report.weekdays
              .map((w) => kWeekdayShort[w.weekday - 1])
              .toList(),
          tooltipLabels: report.weekdays
              .map((w) => kWeekdayLong[w.weekday - 1])
              .toList(),
          series: [
            BarSeries('Index', report.weekdays.map((w) => w.index).toList(),
                kChartPalette[4]),
          ],
          axisFmt: (v) => v.toInt().toString(),
          tooltipFmt: (v) => v.toStringAsFixed(1),
          referenceLine: 100,
          referenceLabel: 'Avg',
          colorFor: (i, v) => v < 90
              ? kBad
              : (v > 110 ? kGood : kChartPalette[4]),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'R3',
        title: 'Barista Scheduling & Staffing',
        subtitle: 'Recommended baristas needed per hour to keep wait times under 3 minutes',
        insights: report.staffingInsights,
        child: ValueBarChart(
          labels: List.generate(24, (i) => i % 3 == 0 ? hourLabel(i) : ''),
          tooltipLabels: List.generate(24, hourLabel),
          series: [
            BarSeries('Expected Orders',
                report.staffing.map((s) => s.expectedOrders).toList(), kChartPalette[3]),
            BarSeries('Staff Needed',
                report.staffing.map((s) => s.staff.toDouble()).toList(), kChartPalette[7]),
          ],
          axisFmt: (v) => v.toInt().toString(),
          tooltipFmt: (v) => v.toStringAsFixed(1),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'R4',
        title: 'Menu Performance Coach (Superstars vs Underperformers)',
        subtitle: 'How to price and feature items to maximize profit',
        insights: report.menuInsights,
        child: QuadrantScatterChart(
          points: report.menu
              .map((m) => ScatterPoint(
                    m.name,
                    m.qty.toDouble(),
                    m.avgPrice,
                    m.cls == MenuClass.star
                        ? kGood
                        : (m.cls == MenuClass.dog ? kBad : kChartPalette[5]),
                    '${m.cls.label} (Qty: ${m.qty}, Price: ${formatPeso(m.avgPrice)})',
                  ))
              .toList(),
          xThreshold: report.popularityThreshold,
          yThreshold: report.priceThreshold,
          xFmt: (v) => v.toInt().toString(),
          yFmt: formatPesoCompact,
          quadrantLabels: const ['Puzzle', 'Star', 'Dog', 'Plowhorse'],
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'R5',
        title: 'Bundle Opportunities',
        subtitle: 'Frequently bought together combinations',
        height: null,
        insights: report.bundleInsights,
        child: HBarChart(
          items: report.bundles
              .map((b) => HBarItem(
                    '${b.a} + ${b.b}',
                    b.count.toDouble(),
                    '${b.count} orders',
                    caption:
                        '${(b.share * 100).toStringAsFixed(1)}% of multi-item orders. Suggested: ${formatPeso(b.bundlePrice)}',
                  ))
              .toList(),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'R6',
        title: 'Product Momentum',
        subtitle: 'Growth (2nd half vs 1st half of period)',
        height: null,
        insights: report.momentumInsights,
        child: HBarChart(
          diverging: true,
          items: report.momentum
              .map((m) => HBarItem(
                    m.name,
                    m.growthPct,
                    m.isNew
                        ? 'New'
                        : '${m.growthPct > 0 ? '+' : ''}${m.growthPct.toStringAsFixed(1)}%',
                    color: m.growthPct > 0 ? kGood : kBad,
                  ))
              .toList(),
        ),
      ),
    ];

    if (isNested) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

// ── Customer Flow & RFM View ─────────────────────────────────────────────────

class _CustomerFlowView extends StatelessWidget {
  final PrescriptiveReport report;
  final bool isNested;
  const _CustomerFlowView({required this.report, this.isNested = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final children = [
      if (!isNested) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.indigo.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.indigo.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.loyalty, color: Colors.indigo, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Loyalty & Regulars Guide',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Recognize your best customers, reward regulars, and re-engage visitors before they slip away. Review each cohort below to see recommended retention actions.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
      AnalyticsChartCard(
        index: 'C1',
        title: 'Customer Loyalty & Regulars (RFM Flow)',
        subtitle: 'Identify VIPs, loyal weekly patrons, and customers who need a win-back discount',
        height: null,
        insights: [
          'Customer retention rate: ${report.retentionRate.toStringAsFixed(1)}%.',
          if (report.churnRiskCount > 0)
            '${report.churnRiskCount} regular customers are at risk of churning – execute re-engagement retention actions.',
        ],
        child: Column(
          children: report.rfmSegments.map((seg) {
            final isVip = seg.name.contains('Champion');
            final isRisk = seg.name.contains('At-Risk');
            final color = isVip
                ? kChartPalette[0]
                : (isRisk ? kWarn : (seg.name.contains('Loyal') ? kChartPalette[2] : kChartPalette[3]));

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isVip
                              ? Icons.workspace_premium
                              : (isRisk ? Icons.warning_amber : Icons.person),
                          color: color,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          seg.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${seg.customerCount} patrons',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    seg.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _MetricChip(label: 'Total Spend', value: formatPeso(seg.totalSpent)),
                      const SizedBox(width: 8),
                      _MetricChip(
                        label: 'Avg Orders',
                        value: seg.avgOrders.toStringAsFixed(1),
                      ),
                      const SizedBox(width: 8),
                      _MetricChip(
                        label: 'Recency',
                        value: '${seg.recencyDays}d ago',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.bolt, size: 16, color: color),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Action: ${seg.action}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 16),
      AnalyticsChartCard(
        index: 'C2',
        title: 'Customer Retention & Churn Flow',
        subtitle: 'Active vs At-Risk customer life-cycle dynamics',
        height: null,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kGood.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kGood.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Retention Rate',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: kGood,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${report.retentionRate.toStringAsFixed(1)}%',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: kGood,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kWarn.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: kWarn.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Churn Warning Count',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: kWarn,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${report.churnRiskCount}',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: kWarn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final ins in report.retentionInsights)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16, color: kGood),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ins,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];

    if (isNested) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}
