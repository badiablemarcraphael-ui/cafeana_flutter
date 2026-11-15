import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/analytics/analytics_engine.dart';
import '../../../core/providers/analytics_providers.dart';
import '../../../core/utils/export_csv_util.dart';
import '../../../core/widgets/animated_glass_card.dart';
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
              'Café Analytics & Decision Dashboard',
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
                  'Live: ${liveSync.ordersCount} orders synced',
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
            tooltip: 'Refresh Live Data',
            onPressed: () {
              refreshLiveFirebaseAnalytics(ref);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing latest orders from database...'),
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
            tooltip: 'Download Excel Report (.xlsx)',
            onPressed: () {
              final r = reportAsync.valueOrNull;
              if (r != null) {
                ExportCsvUtil.exportAnalytics(r, AnalyticsExportSection.full);
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
                'Loading your café analytics...',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Error loading data: $e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => refreshLiveFirebaseAnalytics(ref),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (report) {
          return _SinglePageAllInOneAnalytics(
            report: report,
            selection: selection,
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ONE-PAGE CONSOLIDATED ANALYTICS DASHBOARD (Module 09 Visual Design)
//   • Uses Combination Charts (Columns + Overlaid Forecast Line),
//     Line/Area Charts, Embedded Data Tables, In-Cell Data Bars, Icon Sets,
//     and Color Scale Heatmaps.
//   • Every card integrates:
//       1. DESCRIPTIVE (What happened? Actual columns/line)
//       2. PREDICTIVE  (What may happen? Overlaid forecast comparison line)
//       3. PRESCRIPTIVE (What should we do? Plain-English Action Box at bottom)
// ═════════════════════════════════════════════════════════════════════════════

class _SinglePageAllInOneAnalytics extends StatelessWidget {
  const _SinglePageAllInOneAnalytics({
    required this.report,
    required this.selection,
  });

  final AnalyticsReport report;
  final AnalyticsSelection selection;

  @override
  Widget build(BuildContext context) {
    final desc = report.descriptive;
    final pred = report.predictive;
    final presc = report.prescriptive;

    // ── Determine history window to display for time-series charts ───────────
    final histLen = pred.revenue.history.length;
    final int maxHistToShow;
    switch (selection.preset) {
      case AnalyticsPreset.today:
      case AnalyticsPreset.yesterday:
      case AnalyticsPreset.last7Days:
      case AnalyticsPreset.thisWeek:
        maxHistToShow = 14;
        break;
      case AnalyticsPreset.last30Days:
      case AnalyticsPreset.thisMonth:
      case AnalyticsPreset.lastMonth:
        maxHistToShow = 30;
        break;
      default:
        maxHistToShow = 60;
    }
    final showHistCount = math.min(histLen, maxHistToShow);
    final histOffset = histLen - showHistCount;

    final dispHistDates = pred.revenue.historyDates.sublist(histOffset);
    final forecastDates = pred.revenue.forecastDates;
    final fLen = forecastDates.length;

    final dateFmt = DateFormat('MMM d');
    final fullDateFmt = DateFormat('EEE, MMM d');

    final timeLabels = [
      ...dispHistDates.map(dateFmt.format),
      ...forecastDates.map(dateFmt.format),
    ];
    final timeTooltipLabels = [
      ...dispHistDates.map(fullDateFmt.format),
      ...forecastDates.map((d) => '${fullDateFmt.format(d)} (Forecast)'),
    ];

    // ── CHART 1 DATA: REVENUE TREND (LINE & AREA + PREDICTIVE LINE) ──────────
    final revActualHist = pred.revenue.history.sublist(histOffset);
    final revFittedHist = pred.revenue.model.fitted.length >= histLen
        ? pred.revenue.model.fitted.sublist(histOffset)
        : revActualHist;

    final revActualLine = <double?>[
      ...revActualHist,
      ...List<double?>.filled(fLen, null),
    ];
    final revPredictedLine = <double?>[
      ...revFittedHist,
      ...pred.revenue.forecast,
    ];
    final revConnect = revFittedHist.isNotEmpty
        ? revFittedHist.last
        : (pred.revenue.forecast.isNotEmpty ? pred.revenue.forecast.first : 0.0);
    final revBandLow = <double?>[
      ...List<double?>.filled(math.max(0, revActualHist.length - 1), null),
      if (revActualHist.isNotEmpty) revConnect,
      ...pred.revenue.p10Forecast,
    ];
    final revBandHigh = <double?>[
      ...List<double?>.filled(math.max(0, revActualHist.length - 1), null),
      if (revActualHist.isNotEmpty) revConnect,
      ...pred.revenue.p90Forecast,
    ];

    // ── CHART 2 DATA: ORDER VOLUME (COMBO CHART: COLUMNS + OVERLAID LINE) ────
    final ordActualHist = pred.orders.history.sublist(histOffset);
    final ordFittedHist = pred.orders.model.fitted.length >= histLen
        ? pred.orders.model.fitted.sublist(histOffset)
        : ordActualHist;

    final ordActualCols = <double?>[
      ...ordActualHist,
      ...List<double?>.filled(fLen, null),
    ];
    final ordPredictedLine = <double?>[
      ...ordFittedHist,
      ...pred.orders.forecast,
    ];

    // ── CHART 3 DATA: AVERAGE SPEND PER ORDER / AOV (ACTUAL VS PREDICTED) ────
    final fallbackAov = desc.kpis.aov > 0 ? desc.kpis.aov : 185.0;
    final aovActualHist = List<double>.generate(revActualHist.length, (i) {
      final o = ordActualHist[i];
      return o > 0 ? revActualHist[i] / o : fallbackAov;
    });
    final aovFittedHist = List<double>.generate(revFittedHist.length, (i) {
      final o = ordFittedHist[i];
      return o > 0.5 ? (revFittedHist[i] / o).clamp(80.0, 500.0) : fallbackAov;
    });
    final aovForecast = List<double>.generate(fLen, (i) {
      final o = pred.orders.forecast[i];
      return o > 0.5
          ? (pred.revenue.forecast[i] / o).clamp(80.0, 500.0)
          : fallbackAov;
    });
    final aovActualLine = <double?>[
      ...aovActualHist,
      ...List<double?>.filled(fLen, null),
    ];
    final aovPredictedLine = <double?>[
      ...aovFittedHist,
      ...aovForecast,
    ];

    // ── CHART 4 DATA: TOP-SELLING DRINKS (COMBO CHART + IN-CELL DATA BARS) ───
    final topDrinks = pred.demand.take(7).toList();
    final drinkLabels = topDrinks
        .map((d) => d.name.length > 11 ? '${d.name.substring(0, 9)}…' : d.name)
        .toList();
    final drinkFullLabels = topDrinks.map((d) => d.name).toList();
    final drinkActualCols =
        topDrinks.map<double?>((d) => d.last7Actual.toDouble()).toList();
    final drinkPredictedLine =
        topDrinks.map<double?>((d) => d.next7Forecast).toList();

    final restockMap = {
      for (final r in presc.restock) r.product.name.toLowerCase(): r
    };
    final drinkTableRows = topDrinks.map((d) {
      final r = restockMap[d.name.toLowerCase()];
      final needsReorder = r != null && r.reorderQty > 0;
      return DataBarTableRowData(
        label: d.name,
        actualValue: d.last7Actual.toDouble(),
        actualDisplay: '${d.last7Actual} cups',
        predictedValue: d.next7Forecast,
        predictedDisplay: '${d.next7Forecast.round()} cups',
        statusLabel: needsReorder
            ? 'Order +${r.reorderQty}'
            : (d.growth >= 1.05 ? 'Growing' : 'Healthy'),
        statusLevel: needsReorder ? 0 : 1,
      );
    }).toList();

    // ── CHART 5 DATA: CATEGORY REVENUE (PIE SHARE + COMBO COLUMN/LINE + TABLE)
    final catFlows = pred.categoryFlows;
    final catLabels = catFlows.map((c) => c.category).toList();
    final rangeDays = math.max(1, report.range.days);
    final catActualWeekly = catFlows.map<double?>((c) {
      final totalCatRev = desc.categoryRevenue
          .where((s) => s.label.toLowerCase() == c.category.toLowerCase())
          .fold<double>(0, (a, b) => a + b.value);
      if (totalCatRev > 0) {
        return totalCatRev / rangeDays * 7.0;
      }
      return c.next7Revenue * 0.92;
    }).toList();
    final catPredictedWeekly =
        catFlows.map<double?>((c) => c.next7Revenue).toList();

    // ── CHART 6 DATA: PEAK HOURS (COMBO COLUMNS/LINE + COLOR SCALE HEATMAP) ──
    final activeHours = [for (var h = 7; h <= 22; h++) h];
    final hourLabels = activeHours.map(hourLabel).toList();
    final usualHourlyCols = activeHours
        .map<double?>((h) => desc.hourlyOrders[h] / rangeDays)
        .toList();
    final predictedHourlyLine = activeHours
        .map<double?>((h) => pred.tomorrowHourly[h])
        .toList();
    final heatmapHourVals =
        activeHours.map((h) => pred.tomorrowHourly[h]).toList();

    // ── CHART 7 DATA: SALES BY DAY OF WEEK (COMBO CHART + DATA TABLE BENEATH)
    final weeksCount = math.max(1.0, rangeDays / 7.0);
    final weekdayActualCols = List<double?>.generate(
      7,
      (wIdx) => desc.weekdayRevenue[wIdx] / weeksCount,
    );
    final weekdayPredictedLine = List<double?>.filled(7, 0.0);
    for (var i = 0; i < math.min(7, fLen); i++) {
      final wIdx = forecastDates[i].weekday - 1;
      weekdayPredictedLine[wIdx] = pred.revenue.forecast[i];
    }

    // ── CHART 8 DATA: CUSTOMER LOYALTY (COMBO CHART + DATA TABLE BENEATH) ────
    final rfmSegs = presc.rfmSegments;
    final rfmLabels = [
      'VIP Regulars',
      'Loyal',
      'Big Spenders',
      'Slipping Away',
      'One-Time',
    ];
    final rfmActualCols =
        rfmSegs.map<double?>((s) => s.customerCount.toDouble()).toList();
    final rfmTargetLine = List<double?>.generate(rfmSegs.length, (i) {
      final cur = rfmSegs[i].customerCount.toDouble();
      if (i == 0 || i == 1) return math.max(2.0, (cur * 1.25).roundToDouble());
      if (i == 2) return math.max(2.0, (cur * 1.20).roundToDouble());
      if (i == 3) return (cur * 0.50).floorToDouble();
      return (cur * 0.85).roundToDouble();
    });

    // ── Helper values for plain-English prescriptive boxes ───────────────────
    String slowestDay = 'Tuesday';
    String busiestDay = 'Saturday';
    if (presc.weekdays.isNotEmpty) {
      final sorted = [...presc.weekdays]
        ..sort((a, b) => a.index.compareTo(b.index));
      slowestDay = kWeekdayLong[sorted.first.weekday - 1];
      busiestDay = kWeekdayLong[sorted.last.weekday - 1];
    }

    var peakHour = 14;
    var peakOrders = 0.0;
    for (var h = 0; h < pred.tomorrowHourly.length; h++) {
      if (pred.tomorrowHourly[h] > peakOrders) {
        peakOrders = pred.tomorrowHourly[h];
        peakHour = h;
      }
    }
    final peakBaristas = math.max(1, (peakOrders / 12).ceil());
    final lowStockItems = presc.restock.where((r) => r.reorderQty > 0).toList();
    final topBundle = presc.bundles.isNotEmpty ? presc.bundles.first : null;
    final topDrink = desc.topProducts.isNotEmpty ? desc.topProducts.first : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
      children: [
        // Module 09 Slide 2 Decision Flow Header:
        // 01 RAW DATA -> 02 VISUAL PATTERN -> 03 BUSINESS INSIGHT -> 04 ACTION
        _Module9DecisionFlowBanner(accuracy: pred.revenue.model.accuracy),
        const SizedBox(height: 14),

        // Module 09 Slide 32 Consolidated KPI Row
        _SimpleKpiRow(report: report),
        const SizedBox(height: 18),

        // ── 1. REVENUE TREND (LINE & AREA CHART + FORECAST COMPARISON) ───────
        _UnifiedChartCard(
          stepNumber: '01',
          chartTypeBadge: 'LINE & AREA CHART • TREND OVER TIME',
          title: 'Sales Revenue Trend & 14-Day Forecast',
          subtitle:
              'Descriptive: Actual daily sales (solid area)  •  Predictive: AI comparison & next 14 days (dashed line)',
          headline: formatPeso(desc.kpis.revenue),
          accentColor: kChartPalette[0],
          actualLegendLabel: 'Actual Sales (Descriptive)',
          predictedLegendLabel:
              'Predicted Sales (Predictive • Next 14d: ${formatPeso(pred.revenue.forecastTotal)})',
          showRangeLegend: true,
          chartHeight: 250,
          chart: TrendLineChart(
            labels: timeLabels,
            tooltipLabels: timeTooltipLabels,
            series: [
              LineSeries('Actual Sales', revActualLine, kChartPalette[0],
                  fill: true),
              LineSeries('Predicted Sales', revPredictedLine, kForecast,
                  dashed: true, fill: false),
            ],
            bandLower: revBandLow,
            bandUpper: revBandHigh,
            bandColor: kForecast,
            axisFmt: formatPesoCompact,
            tooltipFmt: formatPeso,
          ),
          prescriptiveTitle: 'What You Should Do to Grow Revenue',
          prescriptivePoints: [
            'Expected sales over the next 14 days: ${formatPeso(pred.revenue.forecastTotal)} (~${formatPeso(pred.revenue.forecastAvg)}/day).',
            'Slow / rainy day budget floor is ${formatPeso(pred.revenue.p10Total / math.max(1, fLen))}/day, while busy days can reach ${formatPeso(pred.revenue.p90Total / math.max(1, fLen))}/day.',
            'Run a 10% discount promo on $slowestDay (your slowest day) to boost mid-week cash flow, and keep full prices on $busiestDay.',
          ],
        ),
        const SizedBox(height: 18),

        // ── 2. ORDER VOLUME (COMBINATION CHART: COLUMNS + OVERLAID LINE) ─────
        _UnifiedChartCard(
          stepNumber: '02',
          chartTypeBadge: 'COMBINATION CHART • COLUMNS + FORECAST LINE',
          title: 'Daily Order Volume vs. Expected Goal',
          subtitle:
              'Descriptive: Columns show actual completed orders  •  Predictive: Overlaid line shows expected orders',
          headline: '${desc.kpis.orders} orders',
          accentColor: kChartPalette[1],
          actualLegendLabel: '▮ Actual Orders (Columns)',
          predictedLegendLabel:
              '● Predicted Orders Line (Next 14d: ~${pred.orders.forecastTotal.round()} orders)',
          chartHeight: 250,
          chart: ComboColumnLineChart(
            labels: timeLabels,
            tooltipLabels: timeTooltipLabels,
            columnName: 'Actual Orders',
            columnValues: ordActualCols,
            columnColor: kChartPalette[1],
            lineName: 'Predicted Orders',
            lineValues: ordPredictedLine,
            lineColor: kForecast,
            axisFmt: (v) => '${v.round()}',
            tooltipFmt: (v) => '${v.toStringAsFixed(1)} orders',
          ),
          prescriptiveTitle: 'What You Should Do for Daily Order Prep',
          prescriptivePoints: [
            'Prepare cups, lids, and ice for ~${pred.orders.forecastAvg.toStringAsFixed(0)} orders per day over the next 2 weeks.',
            'On quiet days expect around ${(pred.orders.p10Total / math.max(1, fLen)).round()} orders; on busy weekend surges prepare for up to ${(pred.orders.p90Total / math.max(1, fLen)).round()} orders.',
            'Keep extra takeout carriers and napkins ready before weekend shifts.',
          ],
        ),
        const SizedBox(height: 18),

        // ── 3. AVERAGE SPEND PER ORDER / AOV (LINE COMPARISON CHART) ─────────
        _UnifiedChartCard(
          stepNumber: '03',
          chartTypeBadge: 'LINE COMPARISON CHART • TICKET SIZE',
          title: 'Average Spend per Order (AOV) vs. Expected Target',
          subtitle:
              'Descriptive: Actual customer spend per order (solid)  •  Predictive: Expected spend comparison (dashed)',
          headline: formatPeso(desc.kpis.aov),
          accentColor: kChartPalette[2],
          actualLegendLabel: 'Actual Spend per Order',
          predictedLegendLabel: 'Predicted Spend per Order',
          chartHeight: 230,
          chart: TrendLineChart(
            labels: timeLabels,
            tooltipLabels: timeTooltipLabels,
            series: [
              LineSeries('Actual AOV', aovActualLine, kChartPalette[2],
                  fill: true),
              LineSeries('Predicted AOV', aovPredictedLine, kForecast,
                  dashed: true, fill: false),
            ],
            axisFmt: formatPesoCompact,
            tooltipFmt: formatPeso,
          ),
          prescriptiveTitle: 'What You Should Do to Increase Spend per Order',
          prescriptivePoints: [
            if (topBundle != null)
              'Create a "${topBundle.a} + ${topBundle.b}" Combo Deal at ${formatPeso(topBundle.bundlePrice)} (10% off regular ${formatPeso(topBundle.regularPrice)}) — customers already bought these together in ${topBundle.count} orders!'
            else
              'Pair your top espresso drinks with a second drink at 10% off to encourage group orders.',
            'Ask every customer at checkout: "Would you like to upgrade to Large or add an extra espresso shot?"',
          ],
        ),
        const SizedBox(height: 18),

        // ── 4. TOP-SELLING DRINKS (COMBO CHART + IN-CELL DATA BARS & ICON SETS)
        _UnifiedChartCard(
          stepNumber: '04',
          chartTypeBadge: 'COMBINATION CHART + IN-CELL DATA BARS & ICON SETS',
          title: 'Top-Selling Drinks: Sold Last 7 Days vs. Next 7-Day Forecast',
          subtitle:
              'Columns & Data Bars compare actual cups sold with predicted cups needed next week & stock status icons',
          headline:
              topDrink != null ? 'Top: ${topDrink.name}' : '${desc.kpis.itemsSold} sold',
          accentColor: kChartPalette[0],
          actualLegendLabel: '▮ Sold Last 7 Days (Columns)',
          predictedLegendLabel: '● Predicted Next 7 Days (Line)',
          chartHeight: 220,
          chart: ComboColumnLineChart(
            labels: drinkLabels,
            tooltipLabels: drinkFullLabels,
            columnName: 'Sold Last 7 Days',
            columnValues: drinkActualCols,
            columnColor: kChartPalette[0],
            lineName: 'Predicted Next 7 Days',
            lineValues: drinkPredictedLine,
            lineColor: kForecast,
            axisFmt: (v) => '${v.round()}',
            tooltipFmt: (v) => '${v.round()} cups',
          ),
          extraVisualUnderChart: DataBarsIconTable(
            rows: drinkTableRows,
            actualHeader: 'Sold Last 7d',
            predictedHeader: 'Next 7d Forecast',
            actualColor: kChartPalette[0],
            predictedColor: kForecast,
          ),
          prescriptiveTitle: 'What You Should Do for Inventory & Menu',
          prescriptivePoints: [
            if (lowStockItems.isNotEmpty)
              'Restock needed soon: ${lowStockItems.take(3).map((r) => '${r.product.name} (order +${r.reorderQty} units)').join(', ')}.'
            else
              'All tracked menu items have enough stock for the next 2 weeks!',
            if (topDrinks.isNotEmpty)
              'Prep the most ingredients for your top 3 upcoming sellers: ${topDrinks.take(3).map((d) => '${d.name} (~${d.next7Forecast.round()} cups next 7 days)').join(', ')}.',
            if (presc.menuInsights.isNotEmpty) presc.menuInsights.first,
          ],
        ),
        const SizedBox(height: 18),

        // ── 5. REVENUE BY CATEGORY (PAIRED PROPORTION PIE + COMBO CHART + TABLE)
        _UnifiedChartCard(
          stepNumber: '05',
          chartTypeBadge: 'PART-TO-WHOLE PIE + COMBINATION CHART WITH DATA TABLE',
          title: 'Sales by Category: Share of Total & Next 7-Day Forecast',
          subtitle:
              'Left: Category share of total revenue  •  Right: Usual weekly columns vs. next 7-day forecast line + table',
          headline: '${catFlows.length} categories',
          accentColor: kChartPalette[4],
          actualLegendLabel: '▮ Usual Weekly Revenue (Columns)',
          predictedLegendLabel: '● Predicted Next 7 Days (Line)',
          chartHeight: 280,
          chart: LayoutBuilder(
            builder: (context, box) {
              final donut = DonutChart(
                slices: desc.categoryRevenue
                    .map((c) => DonutSlice(
                          c.label,
                          c.value,
                          kChartPalette[
                              desc.categoryRevenue.indexOf(c) % kChartPalette.length],
                          display: formatPesoCompact(c.value),
                        ))
                    .toList(),
                centerTitle: 'Total',
                centerValue: formatPesoCompact(
                    desc.categoryRevenue.fold(0, (a, b) => a + b.value)),
              );
              final combo = ComboColumnLineChart(
                labels: catLabels,
                tooltipLabels: catLabels,
                columnName: 'Usual Weekly',
                columnValues: catActualWeekly,
                columnColor: kChartPalette[4],
                lineName: 'Predicted 7d',
                lineValues: catPredictedWeekly,
                lineColor: kForecast,
                axisFmt: formatPesoCompact,
                tooltipFmt: formatPeso,
                showDataTable: true,
              );
              if (box.maxWidth < 640) {
                return combo;
              }
              return Row(
                children: [
                  Expanded(flex: 4, child: donut),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: combo),
                ],
              );
            },
          ),
          prescriptiveTitle: 'What You Should Do per Drink Category',
          prescriptivePoints: [
            if (catFlows.isNotEmpty)
              'Your #1 revenue category is ${catFlows.first.category} (projected ${formatPeso(catFlows.first.next7Revenue)} over the next 7 days) — never let its core ingredients run out.',
            if (catFlows.length > 1)
              'Cross-promote ${catFlows.last.category} alongside ${catFlows.first.category} on your menu board to balance sales across all stations.',
          ],
        ),
        const SizedBox(height: 18),

        // ── 6. PEAK HOURS (COMBO CHART + COLOR SCALE HEATMAP STRIP) ──────────
        _UnifiedChartCard(
          stepNumber: '06',
          chartTypeBadge: 'COMBINATION CHART + COLOR SCALE HEATMAP',
          title: 'Peak Hours: Usual Hourly Traffic vs. Tomorrow\'s Rush Prediction',
          subtitle:
              'Columns show usual hourly orders  •  Overlaid line & heatmap highlight tomorrow\'s peak rush hours',
          headline: 'Peak: ${hourLabel(peakHour)}',
          accentColor: kChartPalette[3],
          actualLegendLabel: '▮ Usual Orders / Hour (Columns)',
          predictedLegendLabel:
              '● Tomorrow\'s Predicted Rush (${DateFormat('EEEE').format(pred.tomorrow)})',
          chartHeight: 230,
          chart: ComboColumnLineChart(
            labels: hourLabels,
            tooltipLabels: hourLabels,
            columnName: 'Usual Hourly Avg',
            columnValues: usualHourlyCols,
            columnColor: kChartPalette[3],
            lineName: 'Predicted Tomorrow',
            lineValues: predictedHourlyLine,
            lineColor: kForecast,
            axisFmt: (v) => v.toStringAsFixed(1),
            tooltipFmt: (v) => '${v.toStringAsFixed(1)} orders/hr',
          ),
          extraVisualUnderChart: ColorScaleHeatmapStrip(
            labels: hourLabels,
            values: heatmapHourVals,
            valueFmt: (v) => v.toStringAsFixed(1),
            title:
                'Color Scale Heatmap — Tomorrow\'s Hourly Rush Intensity (Green = Quiet → Red = Peak Rush)',
          ),
          prescriptiveTitle: 'What You Should Do for Barista Scheduling',
          prescriptivePoints: [
            'Tomorrow\'s biggest rush is expected around ${hourLabel(peakHour)} (~${peakOrders.toStringAsFixed(1)} orders/hour).',
            'Schedule at least $peakBaristas barista(s) during peak hours so customer wait times stay under 3 minutes (1 barista handles ~12 drinks/hour).',
            'Do all syrup refills, milk restocking, and ice prep 1 hour before ${hourLabel(peakHour)}.',
          ],
        ),
        const SizedBox(height: 18),

        // ── 7. SALES BY DAY OF WEEK (COMBO CHART WITH EMBEDDED DATA TABLE) ───
        _UnifiedChartCard(
          stepNumber: '07',
          chartTypeBadge: 'COMBINATION CHART WITH EMBEDDED DATA TABLE',
          title: 'Sales by Day of Week: Usual Average vs. Next 7 Days Forecast',
          subtitle:
              'Columns show usual weekday sales  •  Line shows next week\'s forecast  •  Data table shows exact values',
          headline: 'Best: $busiestDay',
          accentColor: kChartPalette[5],
          actualLegendLabel: '▮ Usual Weekday Avg (Columns)',
          predictedLegendLabel: '● Predicted Next Week (Line)',
          chartHeight: 290,
          chart: ComboColumnLineChart(
            labels: kWeekdayShort,
            tooltipLabels: kWeekdayLong,
            columnName: 'Usual Avg',
            columnValues: weekdayActualCols,
            columnColor: kChartPalette[5],
            lineName: 'Predicted',
            lineValues: weekdayPredictedLine,
            lineColor: kForecast,
            axisFmt: formatPesoCompact,
            tooltipFmt: formatPeso,
            showDataTable: true,
          ),
          prescriptiveTitle: 'What You Should Do Each Week (Promo Calendar)',
          prescriptivePoints: [
            'Slowest sales day: $slowestDay — launch a "Mid-Week Pick-Me-Up" 10% discount or double stamp promo on $slowestDay to fill quiet tables.',
            'Strongest sales day: $busiestDay (+${pred.cashFlow.weekendSurgePct.toStringAsFixed(0)}% weekend boost) — avoid giving discounts on $busiestDay and focus on fast service.',
          ],
        ),
        const SizedBox(height: 18),

        // ── 8. CUSTOMER LOYALTY (COMBO CHART WITH EMBEDDED DATA TABLE) ───────
        _UnifiedChartCard(
          stepNumber: '08',
          chartTypeBadge: 'COMBINATION CHART WITH EMBEDDED DATA TABLE',
          title: 'Customer Loyalty & Repeat Visits: Current vs. Target Goal',
          subtitle:
              'Columns show current customer counts per group  •  Line shows your target retention goal',
          headline: '${presc.retentionRate.toStringAsFixed(0)}% Repeat',
          accentColor: kChartPalette[2],
          actualLegendLabel: '▮ Current Customers (Columns)',
          predictedLegendLabel: '● Target Loyalty Goal (Line)',
          chartHeight: 280,
          chart: ComboColumnLineChart(
            labels: rfmLabels,
            tooltipLabels: rfmSegs.map((s) => s.name).toList(),
            columnName: 'Current',
            columnValues: rfmActualCols,
            columnColor: kChartPalette[2],
            lineName: 'Target Goal',
            lineValues: rfmTargetLine,
            lineColor: kForecast,
            axisFmt: (v) => '${v.round()}',
            tooltipFmt: (v) => '${v.round()} customers',
            showDataTable: true,
          ),
          prescriptiveTitle: 'What You Should Do to Keep Customers Coming Back',
          prescriptivePoints: [
            'Customer retention rate is ${presc.retentionRate.toStringAsFixed(1)}%${desc.avgRating > 0 ? ' with an average rating of ${desc.avgRating.toStringAsFixed(1)} ★' : ''}.',
            if (presc.churnRiskCount > 0)
              '${presc.churnRiskCount} regular customer(s) haven\'t ordered in over 2 weeks ("Slipping Away") — send a "We miss you! 15% off your next coffee" voucher.'
            else
              'Your regular customers are visiting consistently — reward VIP regulars with a free size upgrade or secret menu tasting!',
            'Keep both Dine-In and Take-Out counters stocked with QR payment stands for quick checkout.',
          ],
        ),
      ],
    );
  }
}

// ── Module 09 Slide 2: 4-Step Decision Flow Header ───────────────────────────

class _Module9DecisionFlowBanner extends StatelessWidget {
  const _Module9DecisionFlowBanner({required this.accuracy});
  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _FlowStepPill('01 RAW DATA', 'Live Orders', cs.primary),
              Icon(Icons.arrow_forward, size: 14, color: cs.onSurfaceVariant),
              _FlowStepPill(
                  '02 VISUAL PATTERN', 'Descriptive Actuals', kChartPalette[0]),
              Icon(Icons.arrow_forward, size: 14, color: cs.onSurfaceVariant),
              _FlowStepPill(
                  '03 PREDICTIVE INSIGHT',
                  'AI Forecast (${(accuracy * 100).toStringAsFixed(0)}% Acc)',
                  kForecast),
              Icon(Icons.arrow_forward, size: 14, color: cs.onSurfaceVariant),
              _FlowStepPill(
                  '04 PRESCRIPTIVE ACTION', 'Decide & Monitor', Colors.amber.shade900),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Every visual card below combines Actual Performance (Columns / Solid Line), AI Forecast Comparison (Overlaid Dashed Line), and Action Priorities at the bottom.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowStepPill extends StatelessWidget {
  const _FlowStepPill(this.code, this.label, this.color);
  final String code;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            code,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            '• $label',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Module 09 Slide 32: Consolidated KPI Row ─────────────────────────────────

class _SimpleKpiRow extends StatelessWidget {
  const _SimpleKpiRow({required this.report});
  final AnalyticsReport report;

  @override
  Widget build(BuildContext context) {
    final k = report.descriptive.kpis;
    final p = report.descriptive.previousKpis;
    final revChg = pctChange(k.revenue, p.revenue);
    final ordChg = pctChange(k.orders, p.orders);
    final predTotal = report.predictive.revenue.forecastTotal;
    final lowStockCount =
        report.prescriptive.restock.where((r) => r.reorderQty > 0).length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _SimpleKpiCard(
            kpiCode: 'KPI 01 • TOTAL SALES',
            value: formatPeso(k.revenue),
            subtext: revChg != null
                ? '${revChg >= 0 ? '+' : ''}${revChg.toStringAsFixed(1)}% vs prior period'
                : '${k.orders} completed orders',
            isPositive: (revChg ?? 0) >= 0,
            icon: Icons.payments_outlined,
            color: kChartPalette[0],
          ),
          const SizedBox(width: 10),
          _SimpleKpiCard(
            kpiCode: 'KPI 02 • 14-DAY FORECAST',
            value: formatPeso(predTotal),
            subtext:
                '~${formatPeso(report.predictive.revenue.forecastAvg)} / day expected',
            isPositive: true,
            icon: Icons.trending_up,
            color: kForecast,
          ),
          const SizedBox(width: 10),
          _SimpleKpiCard(
            kpiCode: 'KPI 03 • ORDER VOLUME & AOV',
            value: '${k.orders} orders (${formatPeso(k.aov)} avg)',
            subtext: ordChg != null
                ? '${ordChg >= 0 ? '+' : ''}${ordChg.toStringAsFixed(1)}% (${k.itemsSold} drinks)'
                : '${k.itemsSold} drinks sold',
            isPositive: (ordChg ?? 0) >= 0,
            icon: Icons.receipt_long_outlined,
            color: kChartPalette[1],
          ),
          const SizedBox(width: 10),
          _SimpleKpiCard(
            kpiCode: 'KPI 04 • EXCEPTIONS & RETENTION',
            value: lowStockCount > 0
                ? '$lowStockCount Low Stock Alert(s)'
                : '${report.prescriptive.retentionRate.toStringAsFixed(0)}% Repeat Patrons',
            subtext: lowStockCount > 0
                ? 'Action required in Inventory'
                : '0 stock exceptions • Healthy',
            isPositive: lowStockCount == 0,
            icon: lowStockCount > 0
                ? Icons.warning_amber_rounded
                : Icons.verified_outlined,
            color: lowStockCount > 0 ? kWarn : kGood,
          ),
        ],
      ),
    );
  }
}

class _SimpleKpiCard extends StatelessWidget {
  const _SimpleKpiCard({
    required this.kpiCode,
    required this.value,
    required this.subtext,
    required this.isPositive,
    required this.icon,
    required this.color,
  });

  final String kpiCode;
  final String value;
  final String subtext;
  final bool isPositive;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kpiCode,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.4,
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: isPositive ? kGood : kWarn,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Reusable Module 09 Unified Card ──────────────────────────────────────────

class _UnifiedChartCard extends StatelessWidget {
  const _UnifiedChartCard({
    required this.stepNumber,
    required this.chartTypeBadge,
    required this.title,
    required this.subtitle,
    required this.headline,
    required this.accentColor,
    required this.actualLegendLabel,
    required this.predictedLegendLabel,
    required this.chart,
    required this.prescriptiveTitle,
    required this.prescriptivePoints,
    this.chartHeight = 240,
    this.showRangeLegend = false,
    this.extraVisualUnderChart,
  });

  final String stepNumber;
  final String chartTypeBadge;
  final String title;
  final String subtitle;
  final String headline;
  final Color accentColor;
  final String actualLegendLabel;
  final String predictedLegendLabel;
  final double chartHeight;
  final bool showRangeLegend;
  final Widget chart;
  final Widget? extraVisualUnderChart;
  final String prescriptiveTitle;
  final List<String> prescriptivePoints;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedGlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module 09 Chart Type Tag + 3-Pillar Indicator
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  chartTypeBadge,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: accentColor,
                  ),
                ),
              ),
              Text(
                'DESCRIPTIVE + PREDICTIVE + PRESCRIPTIVE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 1. Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stepNumber,
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  headline,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Legend (Actual vs Predicted Comparison)
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _LegendLineBadge(
                color: accentColor,
                label: actualLegendLabel,
                dashed: false,
              ),
              _LegendLineBadge(
                color: kForecast,
                label: predictedLegendLabel,
                dashed: true,
              ),
              if (showRangeLegend)
                _LegendLineBadge(
                  color: kForecast.withValues(alpha: 0.25),
                  label: 'Expected Range (Slow to Busy Day)',
                  isBox: true,
                ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. The Graph (Descriptive + Predictive Comparison Line inside)
          SizedBox(
            height: chartHeight,
            child: chart,
          ),

          // Optional Module 09 In-Cell Data Bars / Heatmap / Embedded Table
          if (extraVisualUnderChart != null) ...[
            const SizedBox(height: 14),
            extraVisualUnderChart!,
          ],

          const SizedBox(height: 16),

          // 4. Bottom Prescriptive Box ("04 ACTION — What You Should Do")
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amber.shade700.withValues(alpha: 0.30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_rounded,
                      size: 18,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '04 ACTION (Prescriptive) — $prescriptiveTitle',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final point in prescriptivePoints)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            point,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.4,
                              color: cs.onSurface,
                            ),
                          ),
                        ),
                      ],
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

class _LegendLineBadge extends StatelessWidget {
  const _LegendLineBadge({
    required this.color,
    required this.label,
    this.dashed = false,
    this.isBox = false,
  });

  final Color color;
  final String label;
  final bool dashed;
  final bool isBox;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isBox)
          Container(
            width: 14,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: kForecast.withValues(alpha: 0.5)),
            ),
          )
        else if (dashed)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 6, height: 3, color: color),
              const SizedBox(width: 2),
              Container(width: 6, height: 3, color: color),
            ],
          )
        else
          Container(
            width: 14,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
