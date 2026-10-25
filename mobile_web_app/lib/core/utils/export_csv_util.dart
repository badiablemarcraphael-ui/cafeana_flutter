import 'dart:convert';
import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';

import '../analytics/analytics_engine.dart';
import '../models/product.dart';
import '../models/ingredient.dart';

/// Which part of the analytics report to export.
enum AnalyticsExportSection { descriptive, predictive, prescriptive, customerFlow, full }

/// High-precision auto-spaced tabular CSV buffer.
///
/// Automatically measures maximum column widths across each table section,
/// aligning text columns to the left and numeric/currency/percentage columns
/// to the right with exact column padding.
class _TableBuffer {
  final StringBuffer _out = StringBuffer();
  final List<List<String>> _currentTable = [];

  void addRow(List<Object?> cells) {
    if (cells.isEmpty) {
      flush();
      _out.writeln();
      return;
    }
    final firstStr = cells.first?.toString().trim() ?? '';
    if (cells.length == 1 &&
        (firstStr.startsWith('#') ||
            firstStr.startsWith('===') ||
            firstStr.startsWith('Cafeana') ||
            firstStr.startsWith('CAFEANA'))) {
      flush();
      _out.writeln(firstStr);
      return;
    }
    _currentTable.add(cells.map((c) => _esc(c)).toList());
  }

  void addTitle(String title) {
    flush();
    _out.writeln();
    _out.writeln('### $title');
  }

  void flush() {
    if (_currentTable.isEmpty) return;
    final rowCount = _currentTable.length;
    var colCount = 0;
    for (final r in _currentTable) {
      if (r.length > colCount) colCount = r.length;
    }

    final colWidths = List<int>.filled(colCount, 0);
    final isColNumeric = List<bool>.filled(colCount, false);

    for (var c = 0; c < colCount; c++) {
      var numericCount = 0;
      var nonBlankCount = 0;
      for (var r = 0; r < rowCount; r++) {
        final val = c < _currentTable[r].length ? _currentTable[r][c] : '';
        if (val.length > colWidths[c]) {
          colWidths[c] = val.length;
        }
        if (r > 0 || rowCount == 1) {
          final trimmed = val.replaceAll('"', '').trim();
          if (trimmed.isNotEmpty && trimmed != '-' && trimmed != 'n/a') {
            nonBlankCount++;
            if (_isNumeric(trimmed)) {
              numericCount++;
            }
          }
        }
      }
      isColNumeric[c] = nonBlankCount > 0 && (numericCount / nonBlankCount >= 0.70);
    }

    for (var r = 0; r < rowCount; r++) {
      final row = _currentTable[r];
      final formattedCells = <String>[];
      for (var c = 0; c < row.length; c++) {
        final val = row[c];
        final width = colWidths[c];
        if (isColNumeric[c]) {
          formattedCells.add(val.padLeft(width));
        } else {
          formattedCells.add(val.padRight(width));
        }
      }
      _out.writeln(formattedCells.join(', '));
    }

    _currentTable.clear();
  }

  @override
  String toString() {
    flush();
    return _out.toString();
  }

  static bool _isNumeric(String s) {
    final cleaned = s
        .replaceAll('₱', '')
        .replaceAll('\$', '')
        .replaceAll('%', '')
        .replaceAll(',', '')
        .replaceAll('+', '')
        .trim();
    return double.tryParse(cleaned) != null;
  }

  static String _esc(Object? v) {
    final s = v?.toString() ?? '';
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}

class ExportCsvUtil {
  // ── Low-level helpers ──────────────────────────────────────────────────────

  static void _row(_TableBuffer b, List<Object?> cells) => b.addRow(cells);
  static void _title(_TableBuffer b, String t) => b.addTitle(t);

  static String _m(double v) => v.toStringAsFixed(2);
  static String _d(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  static Future<void> _save(String name, String csv) async {
    // UTF-8 BOM so Excel opens the file with the correct encoding.
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    if (kIsWeb) {
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
      return;
    }
    try {
      await FileSaver.instance.saveAs(
        name: name,
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
    } catch (_) {
      await FileSaver.instance.saveFile(
        name: name,
        bytes: bytes,
        fileExtension: 'csv',
        mimeType: MimeType.csv,
      );
    }
  }

  // ── Analytics export ───────────────────────────────────────────────────────

  /// Builds the CSV text for [section]. Exposed for testing.
  static String buildAnalyticsCsv(
      AnalyticsReport r, AnalyticsExportSection section) {
    final b = _TableBuffer();
    _row(b, ['Cafeana Analytics Report']);
    _row(b, ['Section', section.name.toUpperCase()]);
    _row(b, ['Period', r.range.label, r.range.displayDates]);
    _row(b, ['Period start', _d(r.range.start)]);
    _row(b, ['Period end', _d(r.range.lastDay)]);
    _row(b, ['Generated', DateFormat('yyyy-MM-dd HH:mm:ss').format(r.generatedAt)]);
    _row(b, ['Note', 'Revenue = sum of order totals (net of discounts), excluding cancelled orders. Amounts in PHP.']);

    final all = section == AnalyticsExportSection.full;
    if (all || section == AnalyticsExportSection.descriptive) {
      _writeDescriptive(b, r.descriptive);
    }
    if (all || section == AnalyticsExportSection.predictive) {
      _writePredictive(b, r.predictive);
    }
    if (all || section == AnalyticsExportSection.prescriptive) {
      _row(b, []);
      _row(b, ['Prescriptive training window', r.predictive.trainLabel]);
      _writePrescriptive(b, r.prescriptive);
    }
    if (section == AnalyticsExportSection.customerFlow) {
      _row(b, []);
      _row(b, ['Customer Flow & RFM Segmentation Window', r.predictive.trainLabel]);
      _writeCustomerFlow(b, r.prescriptive);
    }
    return b.toString();
  }

  static Future<void> exportAnalytics(
      AnalyticsReport r, AnalyticsExportSection section) async {
    final label = switch (section) {
      AnalyticsExportSection.descriptive => 'Descriptive',
      AnalyticsExportSection.predictive => 'Predictive_ML_Flows',
      AnalyticsExportSection.prescriptive => 'Prescriptive_Action_Plan',
      AnalyticsExportSection.customerFlow => 'Customer_Flow_RFM',
      AnalyticsExportSection.full => 'Full_Flow_Operations',
    };
    await _save('Cafeana_${label}_Analytics_${r.range.fileSuffix}',
        buildAnalyticsCsv(r, section));
  }

  static void _writeDescriptive(_TableBuffer b, DescriptiveReport d) {
    final k = d.kpis;
    final p = d.previousKpis;
    String chg(num c, num pr) {
      final v = pctChange(c, pr);
      return v == null ? 'n/a' : '${v.toStringAsFixed(1)}%';
    }

    _title(b, 'SUMMARY (vs previous ${d.range.days} day period)');
    _row(b, ['Metric', 'Current', 'Previous', 'Change']);
    _row(b, ['Revenue (PHP)', _m(k.revenue), _m(p.revenue), chg(k.revenue, p.revenue)]);
    _row(b, ['Orders (excl. cancelled)', k.orders, p.orders, chg(k.orders, p.orders)]);
    _row(b, ['Average order value (PHP)', _m(k.aov), _m(p.aov), chg(k.aov, p.aov)]);
    _row(b, ['Items sold', k.itemsSold, p.itemsSold, chg(k.itemsSold, p.itemsSold)]);
    _row(b, ['Unique customers', k.customers, p.customers, chg(k.customers, p.customers)]);
    _row(b, ['Cancelled orders', k.cancelled, p.cancelled, chg(k.cancelled, p.cancelled)]);
    _row(b, ['Discounts given (PHP)', _m(k.discounts), _m(p.discounts), chg(k.discounts, p.discounts)]);

    _title(b, 'D1-D3. REVENUE, ORDER VOLUME & AVERAGE ORDER VALUE TREND');
    _row(b, ['Period', 'Revenue (PHP)', 'Orders', 'Avg order value (PHP)']);
    for (var i = 0; i < d.buckets.length; i++) {
      _row(b, [d.buckets[i].fullLabel, _m(d.revenueTrend[i]), d.orderTrend[i], _m(d.aovTrend[i])]);
    }

    _title(b, 'D4. TOP-SELLING PRODUCTS');
    _row(b, ['Rank', 'Product', 'Category', 'Quantity sold', 'Revenue (PHP)', 'Avg price (PHP)']);
    for (var i = 0; i < d.topProducts.length; i++) {
      final t = d.topProducts[i];
      _row(b, [i + 1, t.name, t.category, t.qty, _m(t.revenue), _m(t.avgPrice)]);
    }

    _title(b, 'D5. REVENUE BY CATEGORY');
    final catTotal = d.categoryRevenue.fold<double>(0, (a, c) => a + c.value);
    _row(b, ['Category', 'Revenue (PHP)', 'Share %']);
    for (final c in d.categoryRevenue) {
      _row(b, [c.label, _m(c.value), catTotal == 0 ? '0.0' : (c.value / catTotal * 100).toStringAsFixed(1)]);
    }

    _title(b, 'D6. ORDER STATUS BREAKDOWN');
    final stTotal = d.statusCounts.values.fold<int>(0, (a, c) => a + c);
    _row(b, ['Status', 'Orders', 'Share %']);
    for (final e in d.statusCounts.entries) {
      _row(b, [e.key.label, e.value, stTotal == 0 ? '0.0' : (e.value / stTotal * 100).toStringAsFixed(1)]);
    }

    _title(b, 'D7. PEAK HOURS');
    _row(b, ['Hour', 'Orders', 'Revenue (PHP)']);
    for (var h = 0; h < 24; h++) {
      _row(b, [hourLabel(h), d.hourlyOrders[h], _m(d.hourlyRevenue[h])]);
    }

    _title(b, 'D8. SALES BY DAY OF WEEK');
    _row(b, ['Day', 'Revenue (PHP)', 'Orders', 'Days in period', 'Avg revenue per day (PHP)']);
    for (var w = 0; w < 7; w++) {
      final occ = d.weekdayOccurrences[w];
      _row(b, [kWeekdayLong[w], _m(d.weekdayRevenue[w]), d.weekdayOrders[w], occ,
        _m(occ == 0 ? 0 : d.weekdayRevenue[w] / occ)]);
    }

    _title(b, 'D9. ORDER TYPE');
    _row(b, ['Type', 'Orders', 'Revenue (PHP)']);
    for (final e in d.orderTypeCounts.entries) {
      _row(b, [e.key.label, e.value, _m(d.orderTypeRevenue[e.key] ?? 0)]);
    }

    _title(b, 'D10. CUSTOMER RATINGS');
    _row(b, ['Stars', 'Reviews']);
    for (var i = 4; i >= 0; i--) {
      _row(b, [i + 1, d.ratingCounts[i]]);
    }
    _row(b, ['Average', d.avgRating.toStringAsFixed(2)]);
    _row(b, ['Total reviews', d.ratingTotal]);

    _title(b, 'RAW ORDERS IN PERIOD (for verification)');
    _row(b, ['Order ID', 'Order #', 'Created at', 'Status', 'Payment', 'Type', 'Items', 'Quantity', 'Discount (PHP)', 'Total (PHP)', 'Counted in revenue']);
    for (final o in d.ordersInRange) {
      _row(b, [
        o.id,
        o.orderNumber,
        DateFormat('yyyy-MM-dd HH:mm:ss').format(o.createdAt),
        o.status.label,
        o.paymentStatus.name,
        o.orderType.label,
        o.items.map((i) => '${i.quantity}x ${i.name}').join('; '),
        o.items.fold<int>(0, (a, i) => a + i.quantity),
        _m(o.discountAmount),
        _m(o.total),
        o.status.name == 'cancelled' ? 'No' : 'Yes',
      ]);
    }
  }

  static void _writePredictive(_TableBuffer b, PredictiveReport p) {
    _title(b, 'PREDICTIVE & MACHINE LEARNING MODELS OVERVIEW');
    _row(b, ['Training window', p.trainLabel]);
    _row(b, ['Primary Engine', 'Ensemble Machine Learning (Inverse-Variance Weighted Blend)']);
    _row(b, ['Underlying Models', 'Holt-Winters Triple Smoothing + Ridge Autoregression (AR-7) + Seasonal Linear']);
    if (p.widened) {
      _row(b, ['Note', 'Selected period was adjusted automatically to provide sufficient training history.']);
    }
    _row(b, ['Revenue model accuracy (1-WAPE)', '${(p.revenue.model.accuracy * 100).toStringAsFixed(1)}%']);
    _row(b, ['Orders model accuracy (1-WAPE)', '${(p.orders.model.accuracy * 100).toStringAsFixed(1)}%']);
    _row(b, ['Residual standard deviation (sigma)', _m(p.revenue.model.residualStd)]);

    _title(b, 'P1. MACHINE LEARNING MODEL SCORECARD & PRECISION METRICS');
    _row(b, ['Model Name', 'Algorithm Architecture', 'Accuracy (1-WAPE)', 'MAPE %', 'RMSE', 'Ensemble Weight', 'Algorithm Characteristics']);
    for (final m in p.modelScores) {
      _row(b, [
        m.name,
        m.type,
        '${(m.accuracy * 100).toStringAsFixed(1)}%',
        '${m.mape.toStringAsFixed(1)}%',
        m.rmse.toStringAsFixed(2),
        '${(m.weight * 100).toStringAsFixed(1)}%',
        m.description,
      ]);
    }

    _title(b, 'P2. CASH FLOW SCENARIOS (14-DAY FORWARD RUN RATE)');
    _row(b, ['Projection Horizon', 'Expected Cash Flow (PHP)', 'P10 Conservative (PHP)', 'P90 Optimistic (PHP)', 'Daily Run Rate (PHP/day)', 'Weekend Surge Multiplier']);
    _row(b, [
      'Next ${p.cashFlow.days} Days',
      _m(p.cashFlow.expectedTotal),
      _m(p.cashFlow.p10Pessimistic),
      _m(p.cashFlow.p90Optimistic),
      _m(p.cashFlow.dailyRunRate),
      '+${p.cashFlow.weekendSurgePct.toStringAsFixed(1)}% vs weekdays',
    ]);

    _title(b, 'P3. 14-DAY DETAILED DAILY FORECAST (ENSEMBLE + P10/P90 SCENARIOS)');
    _row(b, ['Date', 'Day', 'Type', 'Revenue Forecast (PHP)', 'Revenue P10 Low (PHP)', 'Revenue P90 High (PHP)', 'Orders Forecast', 'Orders P10 Low', 'Orders P90 High']);
    for (var i = 0; i < p.revenue.historyDates.length; i++) {
      final d = p.revenue.historyDates[i];
      _row(b, [
        _d(d),
        kWeekdayShort[d.weekday - 1],
        'Actual',
        _m(p.revenue.history[i]),
        '',
        '',
        p.orders.history[i].round(),
        '',
        '',
      ]);
    }
    for (var i = 0; i < p.revenue.forecastDates.length; i++) {
      final d = p.revenue.forecastDates[i];
      _row(b, [
        _d(d),
        kWeekdayShort[d.weekday - 1],
        'Forecast',
        _m(p.revenue.forecast[i]),
        _m(p.revenue.p10Forecast[i]),
        _m(p.revenue.p90Forecast[i]),
        p.orders.forecast[i].toStringAsFixed(1),
        p.orders.p10Forecast[i].toStringAsFixed(1),
        p.orders.p90Forecast[i].toStringAsFixed(1),
      ]);
    }
    _row(b, [
      'TOTAL 14-DAY FORECAST',
      '',
      '',
      _m(p.revenue.forecastTotal),
      _m(p.revenue.p10Total),
      _m(p.revenue.p90Total),
      p.orders.forecastTotal.toStringAsFixed(1),
      p.orders.p10Total.toStringAsFixed(1),
      p.orders.p90Total.toStringAsFixed(1),
    ]);

    _title(b, 'P4. PRODUCT DEMAND FORECAST (NEXT 7 DAYS)');
    _row(b, ['Product', 'Units in training window', 'Units/day', 'Trend factor', 'Last 7 days actual', 'Next 7 days forecast']);
    for (final d in p.demand) {
      _row(b, [d.name, d.trainingQty, d.dailyRate.toStringAsFixed(2), d.growth.toStringAsFixed(2), d.last7Actual, d.next7Forecast.toStringAsFixed(1)]);
    }

    _title(b, 'P5. STOCK DEPLETION FORECAST');
    _row(b, ['Product', 'Current stock', 'Forecast units/day', 'Days until stock-out', 'Estimated stock-out date']);
    for (final s in p.depletion) {
      _row(b, [
        s.product.name, s.product.stock, s.dailyDemand.toStringAsFixed(2),
        s.daysLeft == null ? 'No demand' : s.daysLeft!.toStringAsFixed(1),
        s.stockoutDate == null ? '' : _d(s.stockoutDate!),
      ]);
    }

    _title(b, 'P6. CUSTOMER QUEUE FLOW SIMULATION – ${DateFormat('EEEE yyyy-MM-dd').format(p.tomorrow)}');
    _row(b, ['Hour', 'Time of Day', 'Arrival Rate (orders/hr)', 'Active Baristas', 'Hourly Service Capacity', 'Queue Utilization %', 'Estimated Wait (mins)', 'Congestion Status']);
    for (final q in p.queueFlowTomorrow) {
      _row(b, [
        q.hour,
        hourLabel(q.hour),
        q.arrivalRate.toStringAsFixed(2),
        q.activeBaristas,
        q.serviceCapacity,
        '${(q.utilization * 100).toStringAsFixed(1)}%',
        '${q.waitMinutes.toStringAsFixed(1)} min',
        q.status,
      ]);
    }

    _title(b, 'P7. CATEGORY DEMAND FORECAST FLOW (NEXT 7 DAYS)');
    _row(b, ['Category', 'Training Units', 'Next 7 Days Units', 'Next 7 Days Revenue (PHP)', 'Daily Unit Velocity']);
    for (final c in p.categoryFlows) {
      _row(b, [
        c.category,
        c.trainingUnits,
        c.next7Units.toStringAsFixed(1),
        _m(c.next7Revenue),
        (c.next7Units / 7).toStringAsFixed(2),
      ]);
    }

    _title(b, 'P8. MONTHLY REVENUE PROJECTION');
    _row(b, ['Month', 'Status', 'Actual (PHP)', 'Projected remaining (PHP)', 'Total (PHP)']);
    for (final m in p.monthly) {
      _row(b, [DateFormat('MMMM yyyy').format(m.month), m.kind.name, _m(m.actual), _m(m.projected), _m(m.total)]);
    }

    if (p.anomalies.isNotEmpty) {
      _title(b, 'P9. TIME-SERIES ANOMALY DETECTION EVENT LOG');
      _row(b, ['Date', 'Actual (PHP)', 'Expected (PHP)', 'Z-Score', 'Deviation %', 'Event Type', 'Analysis']);
      for (final a in p.anomalies) {
        _row(b, [
          _d(a.date),
          _m(a.actual),
          _m(a.expected),
          a.zScore.toStringAsFixed(2),
          '${a.deviationPct.toStringAsFixed(1)}%',
          a.isSurge ? 'Surge (+)' : 'Drop (-)',
          a.explanation,
        ]);
      }
    }
  }

  static void _writePrescriptive(_TableBuffer b, PrescriptiveReport r) {
    void insights(List<String> list) {
      for (final s in list) {
        _row(b, ['Recommendation', s]);
      }
    }

    _title(b, 'R1. RESTOCK PLAN (cover $kRestockCoverDays days, x$kSafetyStockFactor safety)');
    _row(b, ['Product', 'Current stock', 'Forecast demand', 'Target level', 'Reorder quantity']);
    for (final x in r.restock) {
      _row(b, [x.product.name, x.stock, x.forecastDemand.toStringAsFixed(1), x.targetLevel, x.reorderQty]);
    }
    insights(r.restockInsights);

    _title(b, 'R2. PROMOTION TIMING (weekday performance index, 100 = average day)');
    _row(b, ['Day', 'Avg revenue (PHP)', 'Index', 'Action']);
    for (final w in r.weekdays) {
      _row(b, [kWeekdayLong[w.weekday - 1], _m(w.avgRevenue), w.index.toStringAsFixed(1),
        w.index < 90 ? 'Promote' : (w.index > 110 ? 'Peak – upsell' : 'Maintain')]);
    }
    insights(r.promoInsights);

    _title(b, 'R3. STAFFING PLAN – ${kWeekdayLong[r.busiestWeekday - 1]} (busiest day)');
    _row(b, ['Hour', 'Expected orders', 'Recommended baristas']);
    for (final s in r.staffing) {
      _row(b, [hourLabel(s.hour), s.expectedOrders.toStringAsFixed(2), s.staff]);
    }
    insights(r.staffingInsights);

    _title(b, 'R4. MENU ENGINEERING');
    _row(b, ['Popularity threshold (units)', r.popularityThreshold.toStringAsFixed(1)]);
    _row(b, ['Price threshold (PHP)', _m(r.priceThreshold)]);
    _row(b, ['Product', 'Units sold', 'Revenue (PHP)', 'Avg price (PHP)', 'Class', 'Action']);
    for (final m in r.menu) {
      _row(b, [m.name, m.qty, _m(m.revenue), _m(m.avgPrice), m.cls.label, m.cls.action]);
    }
    insights(r.menuInsights);

    _title(b, 'R5. BUNDLE OPPORTUNITIES');
    _row(b, ['Product A', 'Product B', 'Orders together', '% of multi-item orders', 'Regular price (PHP)', 'Suggested bundle (PHP)']);
    for (final x in r.bundles) {
      _row(b, [x.a, x.b, x.count, (x.share * 100).toStringAsFixed(1), _m(x.regularPrice), _m(x.bundlePrice)]);
    }
    insights(r.bundleInsights);

    _title(b, 'R6. PRODUCT MOMENTUM (2nd half vs 1st half of window)');
    _row(b, ['Product', 'Units 1st half', 'Units 2nd half (normalised)', 'Growth %']);
    for (final m in r.momentum) {
      _row(b, [m.name, m.firstHalf, m.secondHalf, m.isNew ? 'New' : m.growthPct.toStringAsFixed(1)]);
    }
    insights(r.momentumInsights);

    _title(b, 'R7. CUSTOMER RFM SEGMENTATION & CHURN RISK FLOW');
    _row(b, ['Segment', 'Customers', 'Total Spent (PHP)', 'Avg Orders/Customer', 'Avg Recency (Days)', 'Segment Profile', 'Prescriptive Retention Action']);
    for (final s in r.rfmSegments) {
      _row(b, [
        s.name,
        s.customerCount,
        _m(s.totalSpent),
        s.avgOrders.toStringAsFixed(1),
        '${s.recencyDays} days',
        s.description,
        s.action,
      ]);
    }

    _title(b, 'R8. CUSTOMER RETENTION & CHURN METRICS');
    _row(b, ['Metric', 'Value']);
    _row(b, ['Repeat Customer Retention Rate', '${r.retentionRate.toStringAsFixed(1)}%']);
    _row(b, ['At-Risk Churn Warning Count', r.churnRiskCount]);
    insights(r.retentionInsights);
  }

  static void _writeCustomerFlow(_TableBuffer b, PrescriptiveReport r) {
    _title(b, 'CUSTOMER RFM (RECENCY, FREQUENCY, MONETARY) SEGMENTATION');
    _row(b, ['Segment', 'Customers', 'Total Spent (PHP)', 'Avg Orders/Customer', 'Avg Recency (Days)', 'Segment Profile', 'Action Strategy']);
    for (final s in r.rfmSegments) {
      _row(b, [
        s.name,
        s.customerCount,
        _m(s.totalSpent),
        s.avgOrders.toStringAsFixed(1),
        '${s.recencyDays} days',
        s.description,
        s.action,
      ]);
    }

    _title(b, 'RETENTION & CHURN PREVENTION INSIGHTS');
    _row(b, ['Metric', 'Value']);
    _row(b, ['Customer Retention Rate', '${r.retentionRate.toStringAsFixed(1)}%']);
    _row(b, ['At-Risk Churn Customers', r.churnRiskCount]);
    for (final s in r.retentionInsights) {
      _row(b, ['Action Insight', s]);
    }
  }

  // ── Inventory export ────────────────────────────────────────────────────────

  static String _qty(num v) {
    if (v == v.roundToDouble()) {
      return v.toInt().toString();
    }
    return v.toStringAsFixed(2);
  }

  static Map<String, dynamic> _calcCapacity(
    List<RecipeItem> recipe,
    Map<String, Ingredient> ingById,
  ) {
    if (recipe.isEmpty) {
      return {
        'servings': null,
        'bottleneck': 'No recipe',
        'bottleneckStock': null,
        'bottleneckUnit': '',
      };
    }
    int minServings = 999999999;
    String bottleneck = 'None';
    double bottleneckStock = 0;
    String bottleneckUnit = '';

    for (final r in recipe) {
      if (r.quantity <= 0 || r.ingredientId.isEmpty) continue;
      final ing = ingById[r.ingredientId];
      if (ing == null) {
        return {
          'servings': 0,
          'bottleneck': '${r.name} (Missing from stock)',
          'bottleneckStock': 0.0,
          'bottleneckUnit': r.unit,
        };
      }
      final possible = (ing.stockLevel / r.quantity).floor();
      if (possible < minServings) {
        minServings = possible;
        bottleneck = ing.name;
        bottleneckStock = ing.stockLevel;
        bottleneckUnit = ing.unit;
      }
    }
    return {
      'servings': minServings == 999999999 ? 0 : minServings,
      'bottleneck': bottleneck,
      'bottleneckStock': bottleneckStock,
      'bottleneckUnit': bottleneckUnit,
    };
  }

  /// Exports the complete master inventory: stock holdings (packs + units),
  /// pack specifications, Small (12 oz) & Large (16 oz) recipes, and kitchen prep capacity.
  static Future<void> exportFullInventoryReport({
    required List<Ingredient> ingredients,
    required List<Product> products,
  }) async {
    final b = _TableBuffer();

    final lowCount = ingredients.where((i) => i.isLowStock).length;
    final drinksWithRecipe = products
        .where((p) => p.recipe.isNotEmpty || p.recipeSmall.isNotEmpty)
        .length;
    final byId = {for (final i in ingredients) i.id: i};

    // SECTION 1: EXECUTIVE OVERVIEW
    _row(b, ['CAFEANA INVENTORY & RECIPES MASTER REPORT']);
    _row(b, ['Generated', DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())]);
    _row(b, [
      'Scope',
      'Raw Material Stock (Packs & Units), Alert Thresholds, Small 12 oz & Large 16 oz Recipes, Kitchen Capacity'
    ]);
    _row(b, []);

    _title(b, '1. INVENTORY SUMMARY');
    _row(b, ['Metric', 'Count / Value']);
    _row(b, ['Total Raw Ingredients', ingredients.length]);
    _row(b, ['Low Stock Holdings Alert Count', lowCount]);
    _row(b, ['Total Menu Drinks', products.length]);
    _row(b, ['Drinks with Configured Recipe', drinksWithRecipe]);
    _row(b, ['Stock Health Status', lowCount > 0 ? 'ATTENTION REQUIRED ($lowCount low items)' : 'OPTIMAL']);

    // SECTION 2: RAW INGREDIENTS & STOCK HOLDINGS
    _title(b, '2. RAW INGREDIENTS & STOCK HOLDINGS');
    _row(b, [
      'ID',
      'INGREDIENT NAME',
      'CATEGORY',
      'PACK CONTAINER',
      'PACK SIZE',
      'BASE UNIT',
      'PACK SPECIFICATION',
      'PACKS ON HAND',
      'TOTAL UNITS ON HAND',
      'ALERT MIN PACKS',
      'ALERT MIN UNITS',
      'STOCK STATUS',
    ]);
    for (final ing in ingredients) {
      _row(b, [
        ing.id,
        ing.name,
        ing.category,
        ing.packContainer,
        _qty(ing.packQuantity),
        ing.unit,
        '1 ${ing.packContainer} = ${_qty(ing.packQuantity)} ${ing.unit}',
        _qty(ing.packsOnHand),
        '${_qty(ing.stockLevel)} ${ing.unit}',
        _qty(ing.minPacks),
        '${_qty(ing.minStockLevel)} ${ing.unit}',
        ing.isLowStock ? 'LOW STOCK' : 'OPTIMAL',
      ]);
    }

    // SECTION 3: STANDARD OPERATING RECIPES (BOM: 12 OZ SMALL & 16 OZ LARGE)
    _title(b, '3. STANDARD OPERATING RECIPES (BOM: 12 OZ SMALL & 16 OZ LARGE)');
    _row(b, [
      'DRINK ID',
      'DRINK NAME',
      'CATEGORY',
      'COMPONENT INGREDIENT',
      'INGREDIENT ID',
      'UNIT',
      'SMALL (12 OZ) PORTION',
      'LARGE (16 OZ) PORTION',
      'PACK CONTAINER REF',
    ]);
    final sortedDrinks = products
        .where((p) => p.recipe.isNotEmpty || p.recipeSmall.isNotEmpty)
        .toList()
      ..sort((a, b) => (a.itemId ?? a.id).compareTo(b.itemId ?? b.id));

    for (final p in sortedDrinks) {
      final sRecipe = p.recipeFor(DrinkSize.small);
      final lRecipe = p.recipeFor(DrinkSize.large);
      final compIds = <String>{
        ...sRecipe.map((r) => r.ingredientId),
        ...lRecipe.map((r) => r.ingredientId),
      };

      var isFirst = true;
      for (final cid in compIds) {
        final sItem = sRecipe.where((r) => r.ingredientId == cid).firstOrNull;
        final lItem = lRecipe.where((r) => r.ingredientId == cid).firstOrNull;
        final ing = byId[cid];

        final name = lItem?.name ?? sItem?.name ?? ing?.name ?? cid;
        final unit = lItem?.unit ?? sItem?.unit ?? ing?.unit ?? '';
        final sQty = sItem != null ? _qty(sItem.quantity) : '-';
        final lQty = lItem != null ? _qty(lItem.quantity) : '-';
        final containerRef = ing != null
            ? '1 ${ing.packContainer} = ${_qty(ing.packQuantity)} $unit'
            : '';

        _row(b, [
          isFirst ? (p.itemId ?? p.id) : '',
          isFirst ? p.name : '',
          isFirst ? p.category : '',
          name,
          cid,
          unit,
          sQty,
          lQty,
          containerRef,
        ]);
        isFirst = false;
      }
    }

    // SECTION 4: KITCHEN PREP CAPACITY (MAX SERVINGS FROM ON-HAND STOCK)
    _title(b, '4. KITCHEN PREP CAPACITY (MAX SERVINGS FROM ON-HAND STOCK)');
    _row(b, [
      'DRINK ID',
      'DRINK NAME',
      'CATEGORY',
      'MAX SMALL (12 OZ) SERVINGS',
      'MAX LARGE (16 OZ) SERVINGS',
      'LIMITING INGREDIENT (BOTTLENECK)',
      'BOTTLENECK STOCK ON HAND',
    ]);
    for (final p in sortedDrinks) {
      final sCap = _calcCapacity(p.recipeFor(DrinkSize.small), byId);
      final lCap = _calcCapacity(p.recipeFor(DrinkSize.large), byId);

      _row(b, [
        p.itemId ?? p.id,
        p.name,
        p.category,
        sCap['servings']?.toString() ?? 'No recipe',
        lCap['servings']?.toString() ?? 'No recipe',
        lCap['bottleneck']?.toString() ?? 'N/A',
        lCap['bottleneckStock'] != null
            ? '${_qty(lCap['bottleneckStock'] as num)} ${lCap['bottleneckUnit'] ?? ''}'
            : '',
      ]);
    }

    await _save(
      'Cafeana_Inventory_Report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
      b.toString(),
    );
  }

  /// Exports stock holdings only as a single clean spreadsheet for counting and auditing.
  static Future<void> exportStockHoldingsCsv({
    required List<Ingredient> ingredients,
    bool lowStockOnly = false,
  }) async {
    final b = _TableBuffer();
    final target = lowStockOnly ? ingredients.where((i) => i.isLowStock).toList() : ingredients;

    _row(b, [
      'INGREDIENT ID',
      'INGREDIENT NAME',
      'CATEGORY',
      'PACK CONTAINER',
      'PACK SIZE',
      'BASE UNIT',
      'PACK SPECIFICATION',
      'PACKS ON HAND',
      'TOTAL UNITS ON HAND',
      'ALERT MIN PACKS',
      'ALERT MIN UNITS',
      'STOCK STATUS',
      'PHYSICAL COUNT (PACKS)',
      'AUDIT VARIANCE',
    ]);

    for (final ing in target) {
      _row(b, [
        ing.id,
        ing.name,
        ing.category,
        ing.packContainer,
        _qty(ing.packQuantity),
        ing.unit,
        '1 ${ing.packContainer} = ${_qty(ing.packQuantity)} ${ing.unit}',
        _qty(ing.packsOnHand),
        '${_qty(ing.stockLevel)} ${ing.unit}',
        _qty(ing.minPacks),
        '${_qty(ing.minStockLevel)} ${ing.unit}',
        ing.isLowStock ? 'LOW STOCK' : 'OPTIMAL',
        '', // Physical audit count blank for data entry
        '', // Variance blank for audit
      ]);
    }

    final prefix = lowStockOnly ? 'Cafeana_Low_Stock_Alerts' : 'Cafeana_Stock_Holdings';
    await _save(
      '${prefix}_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      b.toString(),
    );
  }

  /// Exports recipe book (BOM) for Small 12 oz and Large 16 oz builds.
  static Future<void> exportDrinkRecipesCsv({
    required List<Product> products,
    required List<Ingredient> ingredients,
  }) async {
    final b = _TableBuffer();
    final byId = {for (final i in ingredients) i.id: i};

    _row(b, [
      'DRINK ID',
      'DRINK NAME',
      'CATEGORY',
      'COMPONENT INGREDIENT',
      'INGREDIENT ID',
      'UNIT',
      'SMALL (12 OZ) PORTION',
      'LARGE (16 OZ) PORTION',
      'PACK CONTAINER',
      'PACK SPECIFICATION',
    ]);

    final drinksWithRecipe = products
        .where((p) => p.recipe.isNotEmpty || p.recipeSmall.isNotEmpty)
        .toList()
      ..sort((a, b) => (a.itemId ?? a.id).compareTo(b.itemId ?? b.id));

    for (final p in drinksWithRecipe) {
      final sRecipe = p.recipeFor(DrinkSize.small);
      final lRecipe = p.recipeFor(DrinkSize.large);
      final compIds = <String>{
        ...sRecipe.map((r) => r.ingredientId),
        ...lRecipe.map((r) => r.ingredientId),
      };

      for (final cid in compIds) {
        final sItem = sRecipe.where((r) => r.ingredientId == cid).firstOrNull;
        final lItem = lRecipe.where((r) => r.ingredientId == cid).firstOrNull;
        final ing = byId[cid];

        final name = lItem?.name ?? sItem?.name ?? ing?.name ?? cid;
        final unit = lItem?.unit ?? sItem?.unit ?? ing?.unit ?? '';
        final sQty = sItem != null ? _qty(sItem.quantity) : '-';
        final lQty = lItem != null ? _qty(lItem.quantity) : '-';

        _row(b, [
          p.itemId ?? p.id,
          p.name,
          p.category,
          name,
          cid,
          unit,
          sQty,
          lQty,
          ing?.packContainer ?? 'pack',
          ing != null ? '1 ${ing.packContainer} = ${_qty(ing.packQuantity)} $unit' : '',
        ]);
      }
    }

    await _save(
      'Cafeana_Drink_Recipes_BOM_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      b.toString(),
    );
  }

  /// Exports a replenishment procurement list for purchasing.
  static Future<void> exportLowStockRestockList({
    required List<Ingredient> ingredients,
  }) async {
    final b = _TableBuffer();
    final lowStock = ingredients.where((i) => i.isLowStock).toList();

    _row(b, [
      'INGREDIENT ID',
      'INGREDIENT NAME',
      'CATEGORY',
      'PACK CONTAINER',
      'PACK SIZE',
      'BASE UNIT',
      'CURRENT PACKS ON HAND',
      'ALERT MIN PACKS',
      'DEFICIT IN PACKS',
      'CURRENT UNITS ON HAND',
      'ALERT MIN UNITS',
      'RECOMMENDED REORDER (PACKS)',
    ]);

    for (final ing in lowStock) {
      final deficit = (ing.minPacks - ing.packsOnHand).clamp(0.0, double.infinity);
      final suggestedReorder = ((ing.minPacks * 2) - ing.packsOnHand).ceil().clamp(1, 9999);

      _row(b, [
        ing.id,
        ing.name,
        ing.category,
        ing.packContainer,
        _qty(ing.packQuantity),
        ing.unit,
        _qty(ing.packsOnHand),
        _qty(ing.minPacks),
        _qty(deficit),
        '${_qty(ing.stockLevel)} ${ing.unit}',
        '${_qty(ing.minStockLevel)} ${ing.unit}',
        suggestedReorder,
      ]);
    }

    await _save(
      'Cafeana_Restock_Procurement_List_${DateFormat('yyyyMMdd').format(DateTime.now())}',
      b.toString(),
    );
  }

  // ── Legacy compatibility wrappers ──────────────────────────────────────────

  static Future<void> exportInventory(List<Product> products, {required bool full}) async {
    final csv = StringBuffer();
    csv.writeln(full ? '=== FULL INVENTORY REPORT ===' : '=== LOW STOCK REPORT ===');
    csv.writeln('Product Name,Category,Current Stock');

    final targetProducts = full ? products : products.where((p) => p.stock != null && p.stock! <= 10).toList();

    for (final p in targetProducts) {
      final name = p.name.replaceAll('"', '""');
      final stock = p.stock ?? 'Unlimited';
      csv.writeln('"$name","${p.category}","$stock"');
    }

    final bytes = Uint8List.fromList(utf8.encode(csv.toString()));
    await FileSaver.instance.saveAs(
      name: full ? 'Full_Inventory' : 'Low_Stock_Inventory',
      bytes: bytes,
      fileExtension: 'csv',
      mimeType: MimeType.csv,
    );
  }

  static Future<void> exportComprehensiveInventoryReport({
    required List<Ingredient> ingredients,
    required List<Product> products,
    List<StandardAddOn>? addOns,
  }) async {
    await exportFullInventoryReport(ingredients: ingredients, products: products);
  }
}
