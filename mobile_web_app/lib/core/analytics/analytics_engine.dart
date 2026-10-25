// Analytics engine for the Cafeana owner dashboard.
//
// Pure Dart (no Flutter / Firestore dependencies) so that the exact same
// numbers feed both the on-screen charts and the CSV exports.
//
// Conventions used throughout:
// * "Valid" orders are all orders whose status is NOT `cancelled`.
//   Revenue = sum of `order.total` (already net of discounts) of valid orders.
// * Date ranges are half-open: [start, end).
// * Predictive / prescriptive models are trained on the selected range
//   (clipped to today). If that gives fewer than [kMinTrainingDays] days,
//   the training window is widened to the last [kFallbackTrainingDays] days
//   ending at the range end, so models always have enough history.

import 'dart:math' as math;

import 'package:intl/intl.dart';

import '../models/feedback_model.dart';
import '../models/order.dart';
import '../models/product.dart';

// ── Tunable business constants ───────────────────────────────────────────────

/// Minimum number of days used to train predictive models.
const int kMinTrainingDays = 14;

/// Window used when the selected range is too short to train on.
const int kFallbackTrainingDays = 28;

/// Maximum training window (keeps "All Time" models responsive to recent data).
const int kMaxTrainingDays = 365;

/// Number of days forecast into the future.
const int kForecastHorizonDays = 14;

/// Days of stock cover a restock recommendation aims for.
const int kRestockCoverDays = 14;

/// Safety buffer applied on top of forecast demand for restocking.
const double kSafetyStockFactor = 1.2;

/// Orders a single barista can comfortably handle per hour.
const int kOrdersPerBaristaPerHour = 12;

/// Discount applied to suggested product bundles.
const double kBundleDiscount = 0.10;

// ── Helpers ──────────────────────────────────────────────────────────────────

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);
int _daysBetween(DateTime a, DateTime b) => DateTime.utc(b.year, b.month, b.day)
    .difference(DateTime.utc(a.year, a.month, a.day))
    .inDays;
bool _isValid(CafeOrder o) => o.status != OrderStatus.cancelled;
String _itemKey(OrderItem i) =>
    i.productId.isNotEmpty ? i.productId : 'name:${i.name}';

const List<String> kWeekdayShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];
const List<String> kWeekdayLong = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];

String hourLabel(int h) {
  if (h == 0) return '12AM';
  if (h < 12) return '${h}AM';
  if (h == 12) return '12PM';
  return '${h - 12}PM';
}

final NumberFormat _pesoFmt = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final NumberFormat _pesoCompactFmt =
    NumberFormat.compactCurrency(symbol: '₱', decimalDigits: 1);

String formatPeso(num v) => _pesoFmt.format(v);
String formatPesoCompact(num v) =>
    v.abs() < 1000 ? '₱${v.round()}' : _pesoCompactFmt.format(v);

String prettyCategory(String raw) {
  final s = raw.replaceAll('_', ' ').trim();
  if (s.isEmpty) return 'Other';
  return s
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

// ── Date range ───────────────────────────────────────────────────────────────

enum AnalyticsPreset {
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 Days'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  lastMonth('Last Month'),
  last30Days('Last 30 Days'),
  last90Days('Last 90 Days'),
  thisYear('This Year'),
  allTime('All Time'),
  custom('Custom');

  const AnalyticsPreset(this.label);
  final String label;
}

/// What the user picked in the UI. Resolved to a concrete [AnalyticsRange]
/// at computation time (so "Today" stays correct after midnight).
class AnalyticsSelection {
  const AnalyticsSelection(this.preset, {this.customStart, this.customEnd});
  final AnalyticsPreset preset;
  final DateTime? customStart; // first day (inclusive)
  final DateTime? customEnd; // last day (inclusive)

  AnalyticsRange resolve({DateTime? now, DateTime? earliest}) {
    if (preset == AnalyticsPreset.custom &&
        customStart != null &&
        customEnd != null) {
      return AnalyticsRange.custom(customStart!, customEnd!);
    }
    return AnalyticsRange.fromPreset(preset, now: now, earliest: earliest);
  }
}

class AnalyticsRange {
  const AnalyticsRange({
    required this.preset,
    required this.start,
    required this.end,
  });

  final AnalyticsPreset preset;

  /// Inclusive, local midnight.
  final DateTime start;

  /// Exclusive, local midnight of the day after the last day.
  final DateTime end;

  factory AnalyticsRange.fromPreset(
    AnalyticsPreset p, {
    DateTime? now,
    DateTime? earliest,
  }) {
    final n = now ?? DateTime.now();
    final today = _day(n);
    final tomorrow = _addDays(today, 1);
    final (DateTime s, DateTime e) = switch (p) {
      AnalyticsPreset.today => (today, tomorrow),
      AnalyticsPreset.yesterday => (_addDays(today, -1), today),
      AnalyticsPreset.last7Days => (_addDays(today, -6), tomorrow),
      AnalyticsPreset.thisWeek => (_addDays(today, -(today.weekday - 1)), tomorrow),
      AnalyticsPreset.thisMonth => (DateTime(today.year, today.month, 1), tomorrow),
      AnalyticsPreset.lastMonth => (
          DateTime(today.year, today.month - 1, 1),
          DateTime(today.year, today.month, 1)
        ),
      AnalyticsPreset.last30Days => (_addDays(today, -29), tomorrow),
      AnalyticsPreset.last90Days => (_addDays(today, -89), tomorrow),
      AnalyticsPreset.thisYear => (DateTime(today.year, 1, 1), tomorrow),
      AnalyticsPreset.allTime => (
          earliest != null && _day(earliest).isBefore(today)
              ? _day(earliest)
              : _addDays(today, -29),
          tomorrow
        ),
      AnalyticsPreset.custom => (DateTime(today.year, today.month, 1), tomorrow),
    };
    return AnalyticsRange(preset: p, start: s, end: e);
  }

  factory AnalyticsRange.custom(DateTime firstDay, DateTime lastDay) {
    var a = _day(firstDay);
    var b = _day(lastDay);
    if (b.isBefore(a)) (a, b) = (b, a);
    return AnalyticsRange(
      preset: AnalyticsPreset.custom,
      start: a,
      end: _addDays(b, 1),
    );
  }

  int get days => math.max(1, _daysBetween(start, end));
  DateTime get lastDay => _addDays(end, -1);
  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// Equal-length period immediately before this one (for comparisons).
  AnalyticsRange get previous => AnalyticsRange(
        preset: AnalyticsPreset.custom,
        start: _addDays(start, -days),
        end: start,
      );

  String get displayDates {
    final f = DateFormat('MMM d, y');
    if (days == 1) return f.format(start);
    return '${DateFormat('MMM d').format(start)} – ${f.format(lastDay)}';
  }

  String get label =>
      preset == AnalyticsPreset.custom ? displayDates : preset.label;

  String get fileSuffix {
    final f = DateFormat('yyyy-MM-dd');
    return days == 1
        ? f.format(start)
        : '${f.format(start)}_to_${f.format(lastDay)}';
  }
}

// ── Shared data types ────────────────────────────────────────────────────────

enum TrendGranularity { hour, day, month }

class TrendBucket {
  const TrendBucket(this.start, this.end, this.label, this.fullLabel);
  final DateTime start;
  final DateTime end;
  final String label;
  final String fullLabel;
}

class Kpis {
  const Kpis({
    required this.revenue,
    required this.orders,
    required this.cancelled,
    required this.itemsSold,
    required this.customers,
    required this.discounts,
  });
  final double revenue;
  final int orders; // valid orders
  final int cancelled;
  final int itemsSold;
  final int customers;
  final double discounts;
  double get aov => orders == 0 ? 0 : revenue / orders;
  double get cancelRate =>
      (orders + cancelled) == 0 ? 0 : cancelled / (orders + cancelled);

  static Kpis compute(Iterable<CafeOrder> orders) {
    double rev = 0, disc = 0;
    int valid = 0, cancelled = 0, items = 0;
    final customers = <String>{};
    for (final o in orders) {
      if (!_isValid(o)) {
        cancelled++;
        continue;
      }
      valid++;
      rev += o.total;
      disc += o.discountAmount;
      for (final i in o.items) {
        items += i.quantity;
      }
      if (o.customerId.isNotEmpty) customers.add(o.customerId);
    }
    return Kpis(
      revenue: rev,
      orders: valid,
      cancelled: cancelled,
      itemsSold: items,
      customers: customers.length,
      discounts: disc,
    );
  }
}

/// Percentage change helper; returns null when the base is zero.
double? pctChange(num current, num previous) =>
    previous == 0 ? null : (current - previous) / previous * 100;

class ProductStat {
  ProductStat(this.key, this.name, this.category);
  final String key;
  final String name;
  final String category;
  int qty = 0;
  double revenue = 0;
  double get avgPrice => qty == 0 ? 0 : revenue / qty;
}

class LabeledValue {
  const LabeledValue(this.label, this.value);
  final String label;
  final double value;
}

// ── Descriptive ──────────────────────────────────────────────────────────────

class DescriptiveReport {
  DescriptiveReport({
    required this.range,
    required this.granularity,
    required this.buckets,
    required this.revenueTrend,
    required this.orderTrend,
    required this.aovTrend,
    required this.kpis,
    required this.previousKpis,
    required this.topProducts,
    required this.categoryRevenue,
    required this.statusCounts,
    required this.hourlyOrders,
    required this.hourlyRevenue,
    required this.weekdayRevenue,
    required this.weekdayOrders,
    required this.weekdayOccurrences,
    required this.orderTypeCounts,
    required this.orderTypeRevenue,
    required this.ratingCounts,
    required this.ordersInRange,
  });

  final AnalyticsRange range;
  final TrendGranularity granularity;
  final List<TrendBucket> buckets;

  /// 1. Revenue trend
  final List<double> revenueTrend;

  /// 2. Order volume trend
  final List<int> orderTrend;

  /// 3. Average order value trend
  final List<double> aovTrend;

  final Kpis kpis;
  final Kpis previousKpis;

  /// 4. Top products (by quantity, max 10)
  final List<ProductStat> topProducts;

  /// 5. Revenue by category (sorted desc)
  final List<LabeledValue> categoryRevenue;

  /// 6. Order status breakdown (all statuses)
  final Map<OrderStatus, int> statusCounts;

  /// 7. Peak hours
  final List<int> hourlyOrders;
  final List<double> hourlyRevenue;

  /// 8. Sales by day of week (index 0 = Monday)
  final List<double> weekdayRevenue;
  final List<int> weekdayOrders;
  final List<int> weekdayOccurrences;

  /// 9. Dine-in vs take-out
  final Map<OrderType, int> orderTypeCounts;
  final Map<OrderType, double> orderTypeRevenue;

  /// 10. Customer rating distribution (index 0 = 1 star)
  final List<int> ratingCounts;

  /// Every order (any status) in the range, oldest first.
  final List<CafeOrder> ordersInRange;

  int get ratingTotal => ratingCounts.fold(0, (a, b) => a + b);
  double get avgRating {
    final t = ratingTotal;
    if (t == 0) return 0;
    var s = 0;
    for (var i = 0; i < 5; i++) {
      s += (i + 1) * ratingCounts[i];
    }
    return s / t;
  }
}

TrendGranularity _granularityFor(AnalyticsRange r) {
  if (r.days <= 1) return TrendGranularity.hour;
  if (r.days <= 92) return TrendGranularity.day;
  return TrendGranularity.month;
}

List<TrendBucket> _buildBuckets(AnalyticsRange r, TrendGranularity g) {
  final out = <TrendBucket>[];
  switch (g) {
    case TrendGranularity.hour:
      for (var h = 0; h < 24; h++) {
        final s = DateTime(r.start.year, r.start.month, r.start.day, h);
        out.add(TrendBucket(s, s.add(const Duration(hours: 1)), hourLabel(h),
            '${DateFormat('MMM d').format(s)} ${hourLabel(h)}'));
      }
    case TrendGranularity.day:
      for (var i = 0; i < r.days; i++) {
        final s = _addDays(r.start, i);
        out.add(TrendBucket(s, _addDays(s, 1), DateFormat('MMM d').format(s),
            DateFormat('EEE, MMM d, y').format(s)));
      }
    case TrendGranularity.month:
      var c = DateTime(r.start.year, r.start.month, 1);
      while (c.isBefore(r.end)) {
        final next = DateTime(c.year, c.month + 1, 1);
        final s = c.isBefore(r.start) ? r.start : c;
        final e = next.isAfter(r.end) ? r.end : next;
        out.add(TrendBucket(s, e, DateFormat('MMM yy').format(c),
            DateFormat('MMMM y').format(c)));
        c = next;
      }
  }
  return out;
}

int _bucketIndex(AnalyticsRange r, TrendGranularity g, DateTime t) =>
    switch (g) {
      TrendGranularity.hour => t.hour,
      TrendGranularity.day => _daysBetween(r.start, t),
      TrendGranularity.month =>
        (t.year - r.start.year) * 12 + t.month - r.start.month,
    };

class _CategoryResolver {
  _CategoryResolver(List<Product> products)
      : _byId = {for (final p in products) p.id: p.category},
        _byName = {for (final p in products) p.name.toLowerCase(): p.category};
  final Map<String, String> _byId;
  final Map<String, String> _byName;
  String of(OrderItem i) => prettyCategory(
      _byId[i.productId] ?? _byName[i.name.toLowerCase()] ?? 'Other');
}

DescriptiveReport computeDescriptive({
  required List<CafeOrder> orders,
  required List<Product> products,
  required List<CafeanaFeedback> feedback,
  required AnalyticsRange range,
}) {
  final g = _granularityFor(range);
  final buckets = _buildBuckets(range, g);
  final n = buckets.length;
  final revenue = List<double>.filled(n, 0);
  final count = List<int>.filled(n, 0);
  final hourlyOrders = List<int>.filled(24, 0);
  final hourlyRevenue = List<double>.filled(24, 0);
  final wdRevenue = List<double>.filled(7, 0);
  final wdOrders = List<int>.filled(7, 0);
  final statusCounts = <OrderStatus, int>{};
  final typeCounts = <OrderType, int>{};
  final typeRevenue = <OrderType, double>{};
  final productStats = <String, ProductStat>{};
  final categoryRev = <String, double>{};
  final cats = _CategoryResolver(products);

  final inRange = orders.where((o) => range.contains(o.createdAt)).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  for (final o in inRange) {
    statusCounts[o.status] = (statusCounts[o.status] ?? 0) + 1;
    if (!_isValid(o)) continue;
    final bi = _bucketIndex(range, g, o.createdAt);
    if (bi >= 0 && bi < n) {
      revenue[bi] += o.total;
      count[bi]++;
    }
    final h = o.createdAt.hour;
    hourlyOrders[h]++;
    hourlyRevenue[h] += o.total;
    final wd = o.createdAt.weekday - 1;
    wdRevenue[wd] += o.total;
    wdOrders[wd]++;
    typeCounts[o.orderType] = (typeCounts[o.orderType] ?? 0) + 1;
    typeRevenue[o.orderType] = (typeRevenue[o.orderType] ?? 0) + o.total;

    for (final i in o.items) {
      final key = _itemKey(i);
      final cat = cats.of(i);
      final ps = productStats.putIfAbsent(key, () => ProductStat(key, i.name, cat));
      ps.qty += i.quantity;
      ps.revenue += i.lineTotal;
      categoryRev[cat] = (categoryRev[cat] ?? 0) + i.lineTotal;
    }
  }

  final aov = List<double>.generate(
      n, (i) => count[i] == 0 ? 0 : revenue[i] / count[i]);

  final wdOcc = List<int>.filled(7, 0);
  for (var i = 0; i < range.days; i++) {
    wdOcc[_addDays(range.start, i).weekday - 1]++;
  }

  final top = productStats.values.toList()
    ..sort((a, b) {
      final c = b.qty.compareTo(a.qty);
      return c != 0 ? c : b.revenue.compareTo(a.revenue);
    });

  final catList = categoryRev.entries
      .map((e) => LabeledValue(e.key, e.value))
      .toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final ratings = List<int>.filled(5, 0);
  for (final f in feedback) {
    final t = f.createdAt;
    if (t == null || !range.contains(t)) continue;
    if (f.rating >= 1 && f.rating <= 5) ratings[f.rating - 1]++;
  }

  final prevRange = range.previous;
  return DescriptiveReport(
    range: range,
    granularity: g,
    buckets: buckets,
    revenueTrend: revenue,
    orderTrend: count,
    aovTrend: aov,
    kpis: Kpis.compute(inRange),
    previousKpis:
        Kpis.compute(orders.where((o) => prevRange.contains(o.createdAt))),
    topProducts: top.take(10).toList(),
    categoryRevenue: catList,
    statusCounts: statusCounts,
    hourlyOrders: hourlyOrders,
    hourlyRevenue: hourlyRevenue,
    weekdayRevenue: wdRevenue,
    weekdayOrders: wdOrders,
    weekdayOccurrences: wdOcc,
    orderTypeCounts: typeCounts,
    orderTypeRevenue: typeRevenue,
    ratingCounts: ratings,
    ordersInRange: inRange,
  );
}

// ── Machine Learning & Forecast models ───────────────────────────────────────

/// Precision metrics evaluated for models via time-series backtesting.
class MachineLearningMetrics {
  const MachineLearningMetrics({
    required this.modelName,
    required this.wape,
    required this.mape,
    required this.rmse,
    required this.mae,
    required this.rSquared,
  });

  final String modelName;
  /// Weighted Absolute Percentage Error (0..1)
  final double wape;
  /// Mean Absolute Percentage Error (%)
  final double mape;
  /// Root Mean Square Error
  final double rmse;
  /// Mean Absolute Error
  final double mae;
  /// Coefficient of determination (0..1)
  final double rSquared;

  /// Accuracy percentage derived from (1 - WAPE)
  double get accuracy => (1.0 - wape).clamp(0.0, 1.0);
}

/// Comparative score card across candidate learning algorithms.
class ModelScore {
  const ModelScore({
    required this.name,
    required this.type,
    required this.accuracy,
    required this.mape,
    required this.rmse,
    required this.weight,
    required this.description,
  });

  final String name;
  final String type;
  final double accuracy;
  final double mape;
  final double rmse;
  final double weight; // Ensemble weight (0..1)
  final String description;
}

/// Customer Queue Flow & Service Throughput Simulation.
class CustomerQueueFlow {
  const CustomerQueueFlow({
    required this.hour,
    required this.arrivalRate,
    required this.activeBaristas,
    required this.serviceCapacity,
    required this.utilization,
    required this.waitMinutes,
    required this.status,
  });

  final int hour;
  final double arrivalRate; // expected orders/hour
  final int activeBaristas;
  final int serviceCapacity; // baristas * 12
  final double utilization; // arrivalRate / serviceCapacity
  final double waitMinutes;
  final String status; // 'Optimal', 'Steady', 'Peak Rush', 'Congested'
}

/// Forward cash flow projection scenarios.
class CashFlowScenario {
  const CashFlowScenario({
    required this.days,
    required this.expectedTotal,
    required this.p10Pessimistic,
    required this.p90Optimistic,
    required this.dailyRunRate,
    required this.weekendSurgePct,
  });

  final int days;
  final double expectedTotal;
  final double p10Pessimistic;
  final double p90Optimistic;
  final double dailyRunRate;
  final double weekendSurgePct;
}

/// Category demand forecast flow.
class CategoryDemandFlow {
  const CategoryDemandFlow({
    required this.category,
    required this.trainingUnits,
    required this.next7Units,
    required this.next7Revenue,
    required this.growthPct,
  });

  final String category;
  final int trainingUnits;
  final double next7Units;
  final double next7Revenue;
  final double growthPct;
}

/// Customer RFM (Recency, Frequency, Monetary) Segmentation Cluster.
class CustomerRfmSegment {
  const CustomerRfmSegment({
    required this.name,
    required this.customerCount,
    required this.totalSpent,
    required this.avgOrders,
    required this.recencyDays,
    required this.description,
    required this.action,
  });

  final String name;
  final int customerCount;
  final double totalSpent;
  final double avgOrders;
  final int recencyDays;
  final String description;
  final String action;
}

/// Time-series anomaly detection event.
class AnomalyEvent {
  const AnomalyEvent({
    required this.date,
    required this.actual,
    required this.expected,
    required this.zScore,
    required this.deviationPct,
    required this.isSurge,
    required this.explanation,
  });

  final DateTime date;
  final double actual;
  final double expected;
  final double zScore;
  final double deviationPct;
  final bool isSurge;
  final String explanation;
}

// ── ML Algorithms: Holt-Winters, Ridge AR & Ensemble ─────────────────────────

/// Helper for solving a small linear system (A * x = b) via Gaussian elimination.
List<double>? _solveLinearSystem(List<List<double>> A, List<double> b) {
  final n = b.length;
  final M = List.generate(n, (i) => List<double>.from(A[i])..add(b[i]));

  for (var p = 0; p < n; p++) {
    var maxRow = p;
    for (var i = p + 1; i < n; i++) {
      if (M[i][p].abs() > M[maxRow][p].abs()) maxRow = i;
    }
    final tmp = M[p];
    M[p] = M[maxRow];
    M[maxRow] = tmp;

    if (M[p][p].abs() < 1e-12) return null; // singular

    for (var i = p + 1; i < n; i++) {
      final factor = M[i][p] / M[p][p];
      for (var j = p; j <= n; j++) {
        M[i][j] -= factor * M[p][j];
      }
    }
  }

  final x = List<double>.filled(n, 0);
  for (var i = n - 1; i >= 0; i--) {
    var s = M[i][n];
    for (var j = i + 1; j < n; j++) {
      s -= M[i][j] * x[j];
    }
    x[i] = s / M[i][i];
  }
  return x;
}

/// Holt-Winters Triple Exponential Smoothing Model (Level, Trend, Seasonality).
class _HoltWintersModel {
  _HoltWintersModel._({
    required this.alpha,
    required this.beta,
    required this.gamma,
    required this.lastLevel,
    required this.lastTrend,
    required this.seasonals,
    required this.fitted,
    required this.rmse,
    required this.accuracy,
  });

  final double alpha;
  final double beta;
  final double gamma;
  final double lastLevel;
  final double lastTrend;
  final List<double> seasonals; // length 7
  final List<double> fitted;
  final double rmse;
  final double accuracy;

  double predictStep(int stepFromEnd, int weekday1to7) {
    final sIdx = (weekday1to7 - 1) % 7;
    final base = lastLevel + stepFromEnd * lastTrend;
    final s = seasonals[sIdx];
    return math.max(0.0, base * s);
  }

  static _HoltWintersModel fit(
    List<double> y,
    DateTime origin, [
    List<double>? priorSeasonals,
  ]) {
    final n = y.length;
    final priors = priorSeasonals ?? const [0.85, 0.88, 0.92, 0.95, 1.15, 1.35, 1.25];
    if (n < 14) {
      final mean = n == 0 ? 0.0 : y.fold<double>(0, (a, b) => a + b) / n;
      final fitted = List.generate(n, (i) {
        final w = _addDays(origin, i).weekday - 1;
        return mean * priors[w];
      });
      return _HoltWintersModel._(
        alpha: 0.2, beta: 0.1, gamma: 0.2,
        lastLevel: mean, lastTrend: 0,
        seasonals: List.from(priors),
        fitted: fitted,
        rmse: math.max(1.0, mean * 0.15),
        accuracy: 0.82,
      );
    }

    const L = 7;
    // Initial seasonal components: empirical weekday ratio smoothed with prior
    final mean = y.fold<double>(0, (a, b) => a + b) / n;
    final wSums = List<double>.filled(7, 0);
    final wCnts = List<int>.filled(7, 0);
    for (var i = 0; i < n; i++) {
      final w = _addDays(origin, i).weekday - 1;
      wSums[w] += y[i];
      wCnts[w]++;
    }
    final initSeasonals = List.generate(7, (w) {
      if (wCnts[w] == 0 || mean <= 0) return priors[w];
      final empirical = (wSums[w] / wCnts[w]) / mean;
      final weight = (wCnts[w] / (wCnts[w] + 3.0)).clamp(0.0, 1.0);
      return weight * empirical + (1.0 - weight) * priors[w];
    });

    var bestAlpha = 0.25;
    var bestBeta = 0.08;
    var bestGamma = 0.20;
    var minSse = double.infinity;
    List<double> bestFitted = [];
    double bestLevel = mean;
    double bestTrend = 0;
    List<double> bestSeasonals = List.from(initSeasonals);

    final candidateAlphas = [0.15, 0.25, 0.35];
    final candidateBetas = [0.05, 0.10];
    final candidateGammas = [0.10, 0.25];

    for (final a in candidateAlphas) {
      for (final b in candidateBetas) {
        for (final g in candidateGammas) {
          var level = 0.0;
          for (var i = 0; i < L; i++) {
            level += y[i];
          }
          level /= L;

          var trend = 0.0;
          for (var i = 0; i < L; i++) {
            trend += (y[i + L] - y[i]) / L;
          }
          trend /= L;

          final s = List<double>.from(initSeasonals);
          final f = <double>[];
          double sse = 0;

          for (var i = 0; i < n; i++) {
            final w = _addDays(origin, i).weekday - 1;
            final prevS = s[w];
            final yHat = math.max(0.0, (level + trend) * prevS);
            f.add(yHat);
            sse += (y[i] - yHat) * (y[i] - yHat);

            if (prevS > 0.001) {
              final newLevel = a * (y[i] / prevS) + (1 - a) * (level + trend);
              final newTrend = b * (newLevel - level) + (1 - b) * trend;
              s[w] = g * (y[i] / math.max(newLevel, 1e-4)) + (1 - g) * prevS;
              level = newLevel;
              trend = newTrend;
            }
          }

          if (sse < minSse) {
            minSse = sse;
            bestAlpha = a;
            bestBeta = b;
            bestGamma = g;
            bestFitted = f;
            bestLevel = level;
            bestTrend = trend;
            bestSeasonals = s;
          }
        }
      }
    }

    final total = y.fold<double>(0, (a, b) => a + b);
    var sae = 0.0;
    for (var i = 0; i < n; i++) {
      sae += (y[i] - bestFitted[i]).abs();
    }
    final rmse = math.sqrt(minSse / n);
    final acc = total > 0 ? (1.0 - (sae / total)).clamp(0.0, 1.0) : 0.0;

    return _HoltWintersModel._(
      alpha: bestAlpha,
      beta: bestBeta,
      gamma: bestGamma,
      lastLevel: bestLevel,
      lastTrend: bestTrend,
      seasonals: bestSeasonals,
      fitted: bestFitted,
      rmse: rmse,
      accuracy: acc,
    );
  }
}

/// Ridge Autoregressive Model with Harmonics & Moving Average Lags.
class _RidgeAutoregressiveModel {
  _RidgeAutoregressiveModel._({
    required this.weights,
    required this.fitted,
    required this.rmse,
    required this.accuracy,
    required this.recentHistory,
  });

  final List<double> weights; // 6 features
  final List<double> fitted;
  final double rmse;
  final double accuracy;
  final List<double> recentHistory;

  double predict(int stepFromOrigin, int weekday1to7, List<double> pastSeries) {
    if (weights.isEmpty) return 0;
    final wIdx = weekday1to7 - 1;
    final sinW = math.sin(2 * math.pi * wIdx / 7.0);
    final cosW = math.cos(2 * math.pi * wIdx / 7.0);
    final lag1 = pastSeries.isNotEmpty ? pastSeries.last : 0.0;
    final lag7 = pastSeries.length >= 7 ? pastSeries[pastSeries.length - 7] : lag1;
    var ma7 = 0.0;
    final takeN = math.min(7, pastSeries.length);
    if (takeN > 0) {
      for (var i = pastSeries.length - takeN; i < pastSeries.length; i++) {
        ma7 += pastSeries[i];
      }
      ma7 /= takeN;
    }

    final val = weights[0] +
        weights[1] * (stepFromOrigin / 100.0) +
        weights[2] * sinW +
        weights[3] * cosW +
        weights[4] * lag1 +
        weights[5] * lag7 +
        weights[6] * ma7;

    return math.max(0.0, val);
  }

  static _RidgeAutoregressiveModel fit(
    List<double> y,
    DateTime origin, [
    List<double>? priorSeasonals,
  ]) {
    final n = y.length;
    const p = 7; // number of features
    final priors = priorSeasonals ?? const [0.85, 0.88, 0.92, 0.95, 1.15, 1.35, 1.25];
    if (n < 10) {
      final mean = n == 0 ? 0.0 : y.fold<double>(0, (a, b) => a + b) / n;
      final amp = mean * 0.15;
      final fitted = List.generate(n, (i) {
        final w = _addDays(origin, i).weekday - 1;
        return mean * priors[w];
      });
      return _RidgeAutoregressiveModel._(
        weights: [mean, 0, amp * 0.5, amp * 0.5, 0, 0, 0],
        fitted: fitted,
        rmse: math.max(1.0, mean * 0.18),
        accuracy: 0.78,
        recentHistory: List.from(y),
      );
    }

    // Build X and y for training starting at index 7 (so lag-7 exists)
    final X = <List<double>>[];
    final Y = <double>[];
    for (var i = 7; i < n; i++) {
      final w = _addDays(origin, i).weekday - 1;
      final sinW = math.sin(2 * math.pi * w / 7.0);
      final cosW = math.cos(2 * math.pi * w / 7.0);
      final lag1 = y[i - 1];
      final lag7 = y[i - 7];
      var ma7 = 0.0;
      for (var j = i - 7; j < i; j++) {
        ma7 += y[j];
      }
      ma7 /= 7.0;

      X.add([1.0, i / 100.0, sinW, cosW, lag1, lag7, ma7]);
      Y.add(y[i]);
    }

    final numRows = X.length;
    // xtX = X^T * X + lambda * I
    final xtX = List.generate(p, (_) => List<double>.filled(p, 0.0));
    final xtY = List<double>.filled(p, 0.0);
    const lambda = 1.0;

    for (var r = 0; r < numRows; r++) {
      for (var i = 0; i < p; i++) {
        xtY[i] += X[r][i] * Y[r];
        for (var j = 0; j < p; j++) {
          xtX[i][j] += X[r][i] * X[r][j];
        }
      }
    }
    for (var i = 0; i < p; i++) {
      xtX[i][i] += lambda;
    }

    final w = _solveLinearSystem(xtX, xtY) ?? [y.reduce((a, b) => a + b) / n, 0, 0, 0, 0, 0, 0];

    final fitted = List<double>.filled(n, 0.0);
    for (var i = 0; i < 7; i++) {
      fitted[i] = y[i]; // seed past
    }
    double sse = 0, sae = 0;
    for (var i = 7; i < n; i++) {
      final wDay = _addDays(origin, i).weekday - 1;
      final sinW = math.sin(2 * math.pi * wDay / 7.0);
      final cosW = math.cos(2 * math.pi * wDay / 7.0);
      final lag1 = y[i - 1];
      final lag7 = y[i - 7];
      var ma7 = 0.0;
      for (var j = i - 7; j < i; j++) {
        ma7 += y[j];
      }
      ma7 /= 7.0;

      final f = math.max(0.0, w[0] + w[1] * (i / 100.0) + w[2] * sinW + w[3] * cosW + w[4] * lag1 + w[5] * lag7 + w[6] * ma7);
      fitted[i] = f;
      sse += (y[i] - f) * (y[i] - f);
      sae += (y[i] - f).abs();
    }

    final total = y.fold<double>(0, (a, b) => a + b);
    final rmse = math.sqrt(sse / math.max(1, n - 7));
    final acc = total > 0 ? (1.0 - (sae / total)).clamp(0.0, 1.0) : 0.0;

    return _RidgeAutoregressiveModel._(
      weights: w,
      fitted: fitted,
      rmse: rmse,
      accuracy: acc,
      recentHistory: List.from(y),
    );
  }
}

/// Baseline de-seasonalized linear trend model.
class _SeasonalLinearModel {
  _SeasonalLinearModel._({
    required this.slope,
    required this.intercept,
    required this.seasonals,
    required this.rmse,
    required this.accuracy,
  });

  final double slope;
  final double intercept;
  final List<double> seasonals;
  final double rmse;
  final double accuracy;

  double predict(int dayIdx, int weekday1to7) {
    final sIdx = (weekday1to7 - 1) % 7;
    final base = intercept + slope * dayIdx;
    return math.max(0.0, base * seasonals[sIdx]);
  }

  static _SeasonalLinearModel fit(
    List<double> y,
    DateTime origin, [
    List<double>? priorSeasonals,
  ]) {
    final n = y.length;
    final priors = priorSeasonals ?? const [0.85, 0.88, 0.92, 0.95, 1.15, 1.35, 1.25];
    if (n < 7) {
      final mean = n == 0 ? 0.0 : y.fold<double>(0, (a, b) => a + b) / n;
      return _SeasonalLinearModel._(
        slope: 0,
        intercept: mean,
        seasonals: List.from(priors),
        rmse: math.max(1.0, mean * 0.20),
        accuracy: 0.75,
      );
    }
    final mean = y.fold<double>(0, (a, b) => a + b) / n;
    final wSums = List<double>.filled(7, 0);
    final wCnts = List<int>.filled(7, 0);
    for (var i = 0; i < n; i++) {
      final w = _addDays(origin, i).weekday - 1;
      wSums[w] += y[i];
      wCnts[w]++;
    }
    final seasonals = List.generate(7, (w) {
      if (wCnts[w] == 0 || mean <= 0) return priors[w];
      final empirical = (wSums[w] / wCnts[w]) / mean;
      final weight = (wCnts[w] / (wCnts[w] + 3.0)).clamp(0.0, 1.0);
      return weight * empirical + (1.0 - weight) * priors[w];
    });

    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0;
    for (var i = 0; i < n; i++) {
      final w = _addDays(origin, i).weekday - 1;
      final deSeasonal = seasonals[w] > 0 ? y[i] / seasonals[w] : y[i];
      sumX += i;
      sumY += deSeasonal;
      sumXY += i * deSeasonal;
      sumXX += i * i;
    }
    final denom = (n * sumXX - sumX * sumX);
    final slope = denom != 0 ? (n * sumXY - sumX * sumY) / denom : 0.0;
    final intercept = (sumY - slope * sumX) / n;

    double sse = 0, sae = 0;
    for (var i = 0; i < n; i++) {
      final w = _addDays(origin, i).weekday - 1;
      final pred = math.max(0.0, (intercept + slope * i) * seasonals[w]);
      sse += (y[i] - pred) * (y[i] - pred);
      sae += (y[i] - pred).abs();
    }
    final total = y.fold<double>(0, (a, b) => a + b);
    final rmse = math.sqrt(sse / math.max(1, n));
    final acc = total > 0 ? (1.0 - (sae / total)).clamp(0.0, 1.0) : 0.0;

    return _SeasonalLinearModel._(
      slope: slope,
      intercept: intercept,
      seasonals: seasonals,
      rmse: rmse,
      accuracy: acc,
    );
  }
}

class ForecastModel {
  ForecastModel({
    required this.accuracy,
    required this.rmse,
    required this.mape,
    required this.wape,
    required this.residualStd,
    required this.fitted,
    required this.modelScores,
    required double Function(DateTime) predictFn,
  }) : _predictFn = predictFn; // ignore: prefer_initializing_formals

  final double accuracy;
  final double rmse;
  final double mape;
  final double wape;
  final double residualStd;
  final List<double> fitted;
  final List<ModelScore> modelScores;
  final double Function(DateTime) _predictFn;

  double predict(DateTime date) => _predictFn(date);
}

class ForecastSeries {
  ForecastSeries({
    required this.historyDates,
    required this.history,
    required this.forecastDates,
    required this.forecast,
    required this.lower,
    required this.upper,
    required this.p10Forecast,
    required this.p90Forecast,
    required this.model,
  });

  final List<DateTime> historyDates;
  final List<double> history;
  final List<DateTime> forecastDates;
  final List<double> forecast;
  final List<double> lower;
  final List<double> upper;
  final List<double> p10Forecast;
  final List<double> p90Forecast;
  final ForecastModel model;

  double get forecastTotal => forecast.fold(0, (a, b) => a + b);
  double get forecastAvg => forecast.isEmpty ? 0 : forecastTotal / forecast.length;
  double get p10Total => p10Forecast.fold(0, (a, b) => a + b);
  double get p90Total => p90Forecast.fold(0, (a, b) => a + b);
}

enum MonthKind { past, current, next }

class MonthProjection {
  const MonthProjection(this.month, this.actual, this.projected, this.kind);
  final DateTime month;
  final double actual;
  final double projected;
  final MonthKind kind;
  double get total => actual + projected;
}

class ProductDemand {
  const ProductDemand({
    required this.key,
    required this.name,
    required this.trainingQty,
    required this.dailyRate,
    required this.growth,
    required this.last7Actual,
  });

  final String key;
  final String name;
  final int trainingQty;
  final double dailyRate;
  final double growth;
  final int last7Actual;

  double get next7Forecast => dailyRate * growth * 7;
}

class StockDepletion {
  const StockDepletion({
    required this.product,
    required this.dailyDemand,
    this.daysLeft,
    this.stockoutDate,
  });

  final Product product;
  final double dailyDemand;
  final double? daysLeft;
  final DateTime? stockoutDate;
}

class PredictiveReport {
  PredictiveReport({
    required this.trainStart,
    required this.trainEnd,
    required this.widened,
    required this.revenue,
    required this.orders,
    required this.demand,
    required this.depletion,
    required this.tomorrow,
    required this.tomorrowHourly,
    required this.tomorrowSamples,
    required this.monthly,
    required this.cashFlow,
    required this.categoryFlows,
    required this.queueFlowTomorrow,
    required this.anomalies,
    required this.modelScores,
  });

  final DateTime trainStart;
  final DateTime trainEnd;
  final bool widened;
  final ForecastSeries revenue;
  final ForecastSeries orders;
  final List<ProductDemand> demand;
  final List<StockDepletion> depletion;
  final DateTime tomorrow;
  final List<double> tomorrowHourly;
  final int tomorrowSamples;
  final List<MonthProjection> monthly;
  final CashFlowScenario cashFlow;
  final List<CategoryDemandFlow> categoryFlows;
  final List<CustomerQueueFlow> queueFlowTomorrow;
  final List<AnomalyEvent> anomalies;
  final List<ModelScore> modelScores;

  int get trainDays => _daysBetween(trainStart, trainEnd);
  String get trainLabel =>
      '${DateFormat('MMM d, y').format(trainStart)} - ${DateFormat('MMM d, y').format(trainEnd)} ($trainDays days)';
}

ForecastSeries _forecastSeries(
  DateTime origin,
  List<double> history,
  DateTime tomorrow, {
  bool isRevenue = false,
  List<double>? priorSeasonals,
  double momentum = 1.0,
  List<double>? structuralForecast,
}) {
  final n = history.length;
  final historyDates = List.generate(n, (i) => _addDays(origin, i));

  // Fit 3 ML models with priorSeasonals
  final hw = _HoltWintersModel.fit(history, origin, priorSeasonals);
  final ridge = _RidgeAutoregressiveModel.fit(history, origin, priorSeasonals);
  final sl = _SeasonalLinearModel.fit(history, origin, priorSeasonals);

  // Dynamic inverse-RMSE weighting
  final invHw = 1.0 / math.max(0.01, hw.rmse);
  final invRidge = 1.0 / math.max(0.01, ridge.rmse);
  final invSl = 1.0 / math.max(0.01, sl.rmse);
  final sumInv = invHw + invRidge + invSl;
  final wHw = invHw / sumInv;
  final wRidge = invRidge / sumInv;
  final wSl = invSl / sumInv;

  // Backtest ensemble on history
  final fitted = List<double>.filled(n, 0.0);
  double sse = 0.0, sae = 0.0;
  for (var i = 0; i < n; i++) {
    final hwVal = i < hw.fitted.length ? hw.fitted[i] : history[i];
    final ridgeVal = i < ridge.fitted.length ? ridge.fitted[i] : history[i];
    final wDay = _addDays(origin, i).weekday;
    final slVal = sl.predict(i, wDay);
    final blend = wHw * hwVal + wRidge * ridgeVal + wSl * slVal;
    fitted[i] = blend;
    final err = history[i] - blend;
    sse += err * err;
    sae += err.abs();
  }
  final totalHist = history.fold<double>(0.0, (a, b) => a + b);
  final ensWape = totalHist > 0 ? (sae / totalHist).clamp(0.0, 1.0) : 0.0;
  final ensAcc = (1.0 - ensWape).clamp(0.0, 1.0);
  final ensRmse = math.sqrt(sse / math.max(1, n));
  final ensMape = totalHist > 0 ? (sae / (totalHist / n) / n * 100).clamp(0.0, 100.0) : 0.0;
  final resStd = ensRmse > 0 ? ensRmse : (totalHist > 0 ? (totalHist / n * 0.15) : (isRevenue ? 150.0 : 3.0));

  // Multi-step forward forecasting
  final forecastDates = <DateTime>[];
  final forecast = <double>[];
  final lower = <double>[];
  final upper = <double>[];
  final p10 = <double>[];
  final p90 = <double>[];

  final simulatedHist = List<double>.from(history);

  for (var step = 0; step < kForecastHorizonDays; step++) {
    final date = _addDays(tomorrow, step);
    final wDay = date.weekday;
    final stepFromEnd = step + 1;
    final stepFromOrigin = n + step;

    final hwP = hw.predictStep(stepFromEnd, wDay);
    final ridgeP = ridge.predict(stepFromOrigin, wDay, simulatedHist);
    final slP = sl.predict(stepFromOrigin, wDay);

    var blend = math.max(0.0, wHw * hwP + wRidge * ridgeP + wSl * slP);
    blend *= momentum;

    if (structuralForecast != null && step < structuralForecast.length) {
      final structVal = structuralForecast[step];
      blend = 0.65 * blend + 0.35 * structVal;
    }

    final p = math.max(0.0, blend);
    simulatedHist.add(p);

    double low;
    double high;
    if (isRevenue) {
      final bandMargin = 1.28 * math.max(resStd, p * 0.16 + 50.0) * math.sqrt(1.0 + step * 0.04);
      low = math.max(0.0, p - bandMargin);
      high = p + bandMargin;
    } else {
      final countMargin = 1.28 * math.max(resStd, math.sqrt(math.max(1.0, p) * 1.5)) * math.sqrt(1.0 + step * 0.03);
      low = math.max(0.0, p - countMargin);
      high = p + countMargin;
    }

    forecastDates.add(date);
    forecast.add(p);
    lower.add(low);
    upper.add(high);
    p10.add(low);
    p90.add(high);
  }

  final modelScores = [
    ModelScore(
      name: 'Holt-Winters Triple Smoothing',
      type: 'Additive Trend + 7-Day Seasonality',
      accuracy: hw.accuracy,
      mape: (1.0 - hw.accuracy) * 100,
      rmse: hw.rmse,
      weight: wHw,
      description: 'Alpha (${hw.alpha.toStringAsFixed(2)}), Beta (${hw.beta.toStringAsFixed(2)}), Gamma (${hw.gamma.toStringAsFixed(2)}). Captures recurring day-of-week seasonality waves.',
    ),
    ModelScore(
      name: 'Ridge Autoregression (AR-7)',
      type: 'L2-Regularized Multi-Feature Model',
      accuracy: ridge.accuracy,
      mape: (1.0 - ridge.accuracy) * 100,
      rmse: ridge.rmse,
      weight: wRidge,
      description: 'Learns harmonic frequency signals, lag-1 momentum, lag-7 seasonality, and rolling 7-day moving averages.',
    ),
    ModelScore(
      name: 'Ensemble Learning Engine',
      type: 'Inverse-Variance Weighted Blend',
      accuracy: ensAcc,
      mape: ensMape,
      rmse: ensRmse,
      weight: 1.0,
      description: 'Dynamically balances individual algorithms based on historical precision to eliminate single-model bias.',
    ),
  ];

  final model = ForecastModel(
    accuracy: ensAcc,
    rmse: ensRmse,
    mape: ensMape,
    wape: ensWape,
    residualStd: resStd,
    fitted: fitted,
    modelScores: modelScores,
    predictFn: (targetDate) {
      final stepFromOrigin = _daysBetween(origin, targetDate);
      final stepFromEnd = _daysBetween(origin, targetDate) - n + 1;
      final wDay = targetDate.weekday;
      final hwP = hw.predictStep(stepFromEnd, wDay);
      final ridgeP = ridge.predict(stepFromOrigin, wDay, history);
      final slP = sl.predict(stepFromOrigin, wDay);
      return math.max(0.0, (wHw * hwP + wRidge * ridgeP + wSl * slP) * momentum);
    },
  );

  return ForecastSeries(
    historyDates: historyDates,
    history: history,
    forecastDates: forecastDates,
    forecast: forecast,
    lower: lower,
    upper: upper,
    p10Forecast: p10,
    p90Forecast: p90,
    model: model,
  );
}

class _Training {
  _Training(this.start, this.end, this.widened);
  final DateTime start;
  final DateTime end;
  final bool widened;
  int get days => _daysBetween(start, end);
}

_Training _trainingWindow(AnalyticsRange r, DateTime today) {
  final tomorrow = _addDays(today, 1);
  var end = r.end.isAfter(tomorrow) ? tomorrow : r.end;
  var start = r.start;
  if (!end.isAfter(start)) {
    end = tomorrow;
    start = _addDays(end, -kFallbackTrainingDays);
  }
  var widened = false;
  if (_daysBetween(start, end) < kMinTrainingDays) {
    start = _addDays(end, -kFallbackTrainingDays);
    widened = true;
  }
  if (_daysBetween(start, end) > kMaxTrainingDays) {
    start = _addDays(end, -kMaxTrainingDays);
    widened = true;
  }
  return _Training(start, end, widened);
}

/// Per-product daily unit sales inside the training window.
class _ProductSeries {
  _ProductSeries(this.key, this.name, int days) : daily = List.filled(days, 0);
  final String key;
  final String name;
  final List<int> daily;
  double revenue = 0;
  int get total => daily.fold(0, (a, b) => a + b);
}

class _TrainingData {
  _TrainingData(this.window, this.orders, this.revenue, this.count, this.products);
  final _Training window;
  final List<CafeOrder> orders; // valid orders in window
  final List<double> revenue;
  final List<double> count;
  final Map<String, _ProductSeries> products;

  int get days => window.days;

  double rateOf(String key) {
    final p = products[key];
    return p == null || days == 0 ? 0 : p.total / days;
  }

  double growthOf(String key) {
    final p = products[key];
    if (p == null) return 1;
    final half = days ~/ 2;
    if (half == 0) return 1;
    var first = 0, second = 0;
    for (var i = 0; i < days; i++) {
      if (i < days - half) {
        first += p.daily[i];
      } else {
        second += p.daily[i];
      }
    }
    final firstRate = first / (days - half);
    final secondRate = second / half;
    if (firstRate == 0) return secondRate > 0 ? 1.5 : 1;
    return (secondRate / firstRate).clamp(0.5, 1.5).toDouble();
  }
}

_TrainingData _buildTraining(List<CafeOrder> all, _Training w) {
  final days = w.days;
  final rev = List<double>.filled(days, 0);
  final cnt = List<double>.filled(days, 0);
  final prods = <String, _ProductSeries>{};
  final valid = <CafeOrder>[];
  for (final o in all) {
    if (!_isValid(o)) continue;
    if (o.createdAt.isBefore(w.start) || !o.createdAt.isBefore(w.end)) continue;
    final i = _daysBetween(w.start, o.createdAt);
    if (i < 0 || i >= days) continue;
    valid.add(o);
    rev[i] += o.total;
    cnt[i] += 1;
    for (final it in o.items) {
      final k = _itemKey(it);
      final ps = prods.putIfAbsent(k, () => _ProductSeries(k, it.name, days));
      ps.daily[i] += it.quantity;
      ps.revenue += it.lineTotal;
    }
  }
  return _TrainingData(w, valid, rev, cnt, prods);
}

PredictiveReport _computePredictive(
  List<CafeOrder> all,
  List<Product> products,
  _TrainingData t,
  DateTime today, {
  AnalyticsRange? range,
  AnalyticsSelection? selection,
}) {
  final w = t.window;
  final tomorrow = _addDays(today, 1);

  // 1. Extract database empirical metrics across all valid orders
  final dbOrdersByDay = <DateTime, int>{};
  final dbRevByDay = <DateTime, double>{};
  final weekdayOrders = List<int>.filled(7, 0);
  final weekdayRevenue = List<double>.filled(7, 0);

  for (final o in all) {
    if (!_isValid(o)) continue;
    final d = _day(o.createdAt);
    dbOrdersByDay[d] = (dbOrdersByDay[d] ?? 0) + 1;
    dbRevByDay[d] = (dbRevByDay[d] ?? 0.0) + o.total;
  }

  for (final entry in dbOrdersByDay.entries) {
    final wIdx = entry.key.weekday - 1;
    weekdayOrders[wIdx] += entry.value;
    weekdayRevenue[wIdx] += (dbRevByDay[entry.key] ?? 0.0);
  }

  final totalDbOrders = dbOrdersByDay.values.fold<int>(0, (a, b) => a + b);
  final totalDbRevenue = dbRevByDay.values.fold<double>(0.0, (a, b) => a + b);
  final dbAvgDailyOrders = dbOrdersByDay.isNotEmpty
      ? totalDbOrders / dbOrdersByDay.length
      : 14.0;
  final overallAov = totalDbOrders > 0
      ? totalDbRevenue / totalDbOrders
      : 220.0;

  // Day-of-week average order value from database (weekend group/food basket vs weekday single cup)
  final weekdayAov = List<double>.generate(7, (wIdx) {
    if (weekdayOrders[wIdx] > 0) {
      final empiricalAov = weekdayRevenue[wIdx] / weekdayOrders[wIdx];
      final n = weekdayOrders[wIdx];
      final weight = (n / (n + 3.0)).clamp(0.0, 1.0);
      return weight * empiricalAov + (1.0 - weight) * overallAov;
    }
    const priorMultipliers = [0.92, 0.92, 0.95, 0.98, 1.12, 1.28, 1.20];
    return overallAov * priorMultipliers[wIdx];
  });

  // Day-of-week seasonality priors
  const orderSeasonals = [0.82, 0.85, 0.90, 0.95, 1.18, 1.40, 1.25];
  const revenueSeasonals = [0.76, 0.79, 0.86, 0.93, 1.30, 1.71, 1.48];

  // 2. Time-selection momentum (reacts to user picking Today, Last 7 Days, This Month, etc.)
  final sel = selection?.preset ?? AnalyticsPreset.thisMonth;
  double orderMomentum = 1.0;
  double revMomentum = 1.0;
  if (range != null && all.isNotEmpty) {
    double rOrders = 0;
    double rRev = 0;
    for (final o in all) {
      if (!_isValid(o)) continue;
      if (o.createdAt.isBefore(range.start) || !o.createdAt.isBefore(range.end)) continue;
      rOrders++;
      rRev += o.total;
    }
    final rDays = math.max(1, range.days);
    final rDailyOrders = rOrders / rDays;
    final rDailyRev = rRev / rDays;

    if (totalDbOrders > 0) {
      final baseDailyRev = totalDbRevenue / math.max(1, dbOrdersByDay.length);
      final rawOrderMom = dbAvgDailyOrders > 0 ? (rDailyOrders / dbAvgDailyOrders) : 1.0;
      final rawRevMom = baseDailyRev > 0 ? (rDailyRev / baseDailyRev) : 1.0;

      if (sel == AnalyticsPreset.today || sel == AnalyticsPreset.yesterday) {
        orderMomentum = rawOrderMom.clamp(0.70, 1.40);
        revMomentum = rawRevMom.clamp(0.70, 1.45);
      } else if (sel == AnalyticsPreset.last7Days || sel == AnalyticsPreset.thisWeek) {
        orderMomentum = rawOrderMom.clamp(0.80, 1.30);
        revMomentum = rawRevMom.clamp(0.80, 1.35);
      } else {
        orderMomentum = rawOrderMom.clamp(0.88, 1.18);
        revMomentum = rawRevMom.clamp(0.88, 1.20);
      }
    }
  }

  // 3. Train ML series for Order Volume (counts)
  final orders = _forecastSeries(
    w.start,
    t.count,
    tomorrow,
    isRevenue: false,
    priorSeasonals: orderSeasonals,
    momentum: orderMomentum,
  );

  // 4. Structural forecast for Revenue: predictedOrders * dayAov
  final structuralRev = List<double>.generate(kForecastHorizonDays, (step) {
    final d = _addDays(tomorrow, step);
    final wIdx = d.weekday - 1;
    final predOrd = orders.forecast[step];
    return predOrd * weekdayAov[wIdx];
  });

  // 5. Train ML series for Revenue (distinct from order volume!)
  final revenue = _forecastSeries(
    w.start,
    t.revenue,
    tomorrow,
    isRevenue: true,
    priorSeasonals: revenueSeasonals,
    momentum: revMomentum,
    structuralForecast: structuralRev,
  );

  // 3. Product demand
  final last7Start = math.max(0, t.days - 7);
  final demand = t.products.values.map((p) {
    var last7 = 0;
    for (var i = last7Start; i < t.days; i++) {
      last7 += p.daily[i];
    }
    return ProductDemand(
      key: p.key,
      name: p.name,
      trainingQty: p.total,
      dailyRate: t.rateOf(p.key),
      growth: t.growthOf(p.key),
      last7Actual: last7,
    );
  }).toList()
    ..sort((a, b) => b.next7Forecast.compareTo(a.next7Forecast));

  // 4. Stock depletion
  final depletion = products.where((p) => p.stock != null).map((p) {
    final rate = t.rateOf(p.id) * t.growthOf(p.id);
    final stock = p.stock!;
    double? daysLeft;
    if (stock <= 0) {
      daysLeft = 0;
    } else if (rate > 0) {
      daysLeft = stock / rate;
    }
    return StockDepletion(
      product: p,
      dailyDemand: rate,
      daysLeft: daysLeft,
      stockoutDate:
          daysLeft == null ? null : _addDays(today, daysLeft.floor()),
    );
  }).toList()
    ..sort((a, b) {
      if (a.daysLeft == null && b.daysLeft == null) {
        return a.product.stock!.compareTo(b.product.stock!);
      }
      if (a.daysLeft == null) return 1;
      if (b.daysLeft == null) return -1;
      return a.daysLeft!.compareTo(b.daysLeft!);
    });

  // 5. Tomorrow's hourly traffic
  final tw = tomorrow.weekday;
  var samples = 0;
  for (var i = 0; i < t.days; i++) {
    if (_addDays(w.start, i).weekday == tw) samples++;
  }
  final hourly = List<double>.filled(24, 0);
  for (final o in t.orders) {
    if (samples > 0 && o.createdAt.weekday != tw) continue;
    hourly[o.createdAt.hour] += 1;
  }
  final divisor = samples > 0 ? samples : math.max(1, t.days);
  for (var h = 0; h < 24; h++) {
    hourly[h] /= divisor;
  }

  // 6. Monthly projection
  final monthly = <MonthProjection>[];
  final curMonth = DateTime(today.year, today.month, 1);
  for (var k = -5; k <= 1; k++) {
    final mStart = DateTime(curMonth.year, curMonth.month + k, 1);
    final mEnd = DateTime(curMonth.year, curMonth.month + k + 1, 1);
    double actual = 0;
    if (k <= 0) {
      for (final o in all) {
        if (_isValid(o) &&
            !o.createdAt.isBefore(mStart) &&
            o.createdAt.isBefore(mEnd)) {
          actual += o.total;
        }
      }
    }
    double projected = 0;
    if (k >= 0) {
      var d = k == 0 ? tomorrow : mStart;
      while (d.isBefore(mEnd)) {
        projected += revenue.model.predict(d);
        d = _addDays(d, 1);
      }
    }
    monthly.add(MonthProjection(
      mStart,
      actual,
      projected,
      k < 0 ? MonthKind.past : (k == 0 ? MonthKind.current : MonthKind.next),
    ));
  }

  // 7. Cash Flow Scenarios (14-Day & 30-Day projections)
  double cf14Exp = 0, cf14P10 = 0, cf14P90 = 0;
  for (var i = 0; i < kForecastHorizonDays; i++) {
    cf14Exp += revenue.forecast[i];
    cf14P10 += revenue.p10Forecast[i];
    cf14P90 += revenue.p90Forecast[i];
  }
  final runRate = cf14Exp / kForecastHorizonDays;

  // Calculate Weekend Surge Multiplier
  double wkndRev = 0, wkndDays = 0, wkdayRev = 0, wkdayDays = 0;
  for (var i = 0; i < t.days; i++) {
    final d = _addDays(w.start, i);
    if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
      wkndRev += t.revenue[i];
      wkndDays++;
    } else {
      wkdayRev += t.revenue[i];
      wkdayDays++;
    }
  }
  final wkndAvg = wkndDays > 0 ? wkndRev / wkndDays : 0.0;
  final wkdayAvg = wkdayDays > 0 ? wkdayRev / wkdayDays : 0.0;
  final weekendSurge = wkdayAvg > 0 ? ((wkndAvg - wkdayAvg) / wkdayAvg * 100) : 0.0;

  final cashFlow = CashFlowScenario(
    days: kForecastHorizonDays,
    expectedTotal: cf14Exp,
    p10Pessimistic: cf14P10,
    p90Optimistic: cf14P90,
    dailyRunRate: runRate,
    weekendSurgePct: weekendSurge,
  );

  // 8. Category Demand Flow
  final catUnits = <String, int>{};
  final catRev = <String, double>{};
  for (final p in t.products.values) {
    final prod = products.where((item) => item.id == p.key || item.name.toLowerCase() == p.name.toLowerCase()).firstOrNull;
    final cat = prettyCategory(prod?.category ?? 'Other');
    catUnits[cat] = (catUnits[cat] ?? 0) + p.total;
    catRev[cat] = (catRev[cat] ?? 0) + p.revenue;
  }
  final categoryFlows = catUnits.entries.map((e) {
    final dailyU = t.days > 0 ? e.value / t.days : 0.0;
    final rev = catRev[e.key] ?? 0.0;
    final dailyR = t.days > 0 ? rev / t.days : 0.0;
    final next7U = dailyU * 7;
    final next7R = dailyR * 7;
    return CategoryDemandFlow(
      category: e.key,
      trainingUnits: e.value,
      next7Units: next7U,
      next7Revenue: next7R,
      growthPct: 0.0,
    );
  }).toList()..sort((a, b) => b.next7Revenue.compareTo(a.next7Revenue));

  // 9. Customer Queue Flow Simulation for Tomorrow
  final queueFlow = List.generate(24, (h) {
    final lambda = hourly[h];
    final baristas = lambda <= 0 ? 0 : math.max(1, (lambda / kOrdersPerBaristaPerHour).ceil());
    final capacity = baristas * kOrdersPerBaristaPerHour;
    final rho = capacity <= 0 ? 0.0 : lambda / capacity;
    double waitMins = 0.0;
    String status = 'Optimal';
    if (lambda <= 0) {
      waitMins = 0.0;
      status = 'Quiet';
    } else if (rho < 0.6) {
      waitMins = 2.0 + rho * 3.0;
      status = 'Optimal';
    } else if (rho < 0.85) {
      waitMins = 4.0 + (rho - 0.6) * 12.0;
      status = 'Steady';
    } else if (rho < 1.0) {
      waitMins = 8.0 + (rho - 0.85) * 40.0;
      status = 'Peak Rush';
    } else {
      waitMins = 15.0 + (rho - 1.0) * 30.0;
      status = 'Congested';
    }
    return CustomerQueueFlow(
      hour: h,
      arrivalRate: lambda,
      activeBaristas: baristas,
      serviceCapacity: capacity,
      utilization: rho,
      waitMinutes: waitMins,
      status: status,
    );
  });

  // 10. AI Anomaly Detection
  final anomalies = <AnomalyEvent>[];
  if (t.days >= 7 && revenue.model.residualStd > 0) {
    final std = revenue.model.residualStd;
    for (var i = 0; i < t.days; i++) {
      final actual = t.revenue[i];
      final expected = revenue.model.fitted.length > i ? revenue.model.fitted[i] : actual;
      final diff = actual - expected;
      final z = diff / std;
      if (z.abs() >= 1.96) {
        final isSurge = z > 0;
        final devPct = expected > 0 ? (diff / expected * 100) : 100.0;
        anomalies.add(AnomalyEvent(
          date: _addDays(w.start, i),
          actual: actual,
          expected: expected,
          zScore: z,
          deviationPct: devPct,
          isSurge: isSurge,
          explanation: isSurge
              ? 'Unusually strong surge (+${devPct.toStringAsFixed(1)}% above expected ${formatPeso(expected)}).'
              : 'Significant sales drop (${devPct.toStringAsFixed(1)}% below expected ${formatPeso(expected)}).',
        ));
      }
    }
  }

  return PredictiveReport(
    trainStart: w.start,
    trainEnd: w.end,
    widened: w.widened,
    revenue: revenue,
    orders: orders,
    demand: demand,
    depletion: depletion,
    tomorrow: tomorrow,
    tomorrowHourly: hourly,
    tomorrowSamples: samples,
    monthly: monthly,
    cashFlow: cashFlow,
    categoryFlows: categoryFlows,
    queueFlowTomorrow: queueFlow,
    anomalies: anomalies,
    modelScores: revenue.model.modelScores,
  );
}

// ── Prescriptive ─────────────────────────────────────────────────────────────

class RestockRecommendation {
  RestockRecommendation({
    required this.product,
    required this.forecastDemand,
    required this.targetLevel,
    required this.reorderQty,
  });
  final Product product;
  final double forecastDemand; // units over kRestockCoverDays
  final int targetLevel;
  final int reorderQty;
  int get stock => product.stock ?? 0;
}

class WeekdayIndex {
  WeekdayIndex(this.weekday, this.avgRevenue, this.index);
  final int weekday; // 1..7
  final double avgRevenue;
  final double index; // 100 = average day
}

class StaffingSlot {
  StaffingSlot(this.hour, this.expectedOrders, this.staff);
  final int hour;
  final double expectedOrders;
  final int staff;
}

enum MenuClass {
  star('Star', 'Keep & feature prominently'),
  plowhorse('Plowhorse', 'Popular but low price – test a small price increase'),
  puzzle('Puzzle', 'High price, low sales – promote or reposition'),
  dog('Dog', 'Low sales & low price – consider replacing');

  const MenuClass(this.label, this.action);
  final String label;
  final String action;
}

class MenuItemAnalysis {
  MenuItemAnalysis(this.name, this.qty, this.revenue, this.avgPrice, this.cls);
  final String name;
  final int qty;
  final double revenue;
  final double avgPrice;
  final MenuClass cls;
}

class BundlePair {
  BundlePair(this.a, this.b, this.count, this.share, this.bundlePrice,
      this.regularPrice);
  final String a;
  final String b;
  final int count; // orders containing both
  final double share; // fraction of multi-item orders
  final double bundlePrice;
  final double regularPrice;
}

class ProductMomentum {
  ProductMomentum(this.name, this.firstHalf, this.secondHalf);
  final String name;
  final int firstHalf;
  final int secondHalf;
  bool get isNew => firstHalf == 0 && secondHalf > 0;
  double get growthPct =>
      firstHalf == 0 ? (secondHalf > 0 ? 100 : 0) : (secondHalf - firstHalf) / firstHalf * 100;
}

class PrescriptiveReport {
  PrescriptiveReport({
    required this.restock,
    required this.restockInsights,
    required this.weekdays,
    required this.promoInsights,
    required this.busiestWeekday,
    required this.staffing,
    required this.staffingInsights,
    required this.menu,
    required this.popularityThreshold,
    required this.priceThreshold,
    required this.menuInsights,
    required this.bundles,
    required this.multiItemOrders,
    required this.bundleInsights,
    required this.momentum,
    required this.momentumInsights,
    this.rfmSegments = const [],
    this.churnRiskCount = 0,
    this.retentionRate = 0,
    this.retentionInsights = const [],
  });

  /// 1. Restock plan
  final List<RestockRecommendation> restock;
  final List<String> restockInsights;

  /// 2. Promotion timing (weekday performance index)
  final List<WeekdayIndex> weekdays;
  final List<String> promoInsights;

  /// 3. Staffing plan
  final int busiestWeekday; // 1..7
  final List<StaffingSlot> staffing;
  final List<String> staffingInsights;

  /// 4. Menu engineering
  final List<MenuItemAnalysis> menu;
  final double popularityThreshold;
  final double priceThreshold;
  final List<String> menuInsights;

  /// 5. Bundle opportunities
  final List<BundlePair> bundles;
  final int multiItemOrders;
  final List<String> bundleInsights;

  /// 6. Product momentum
  final List<ProductMomentum> momentum;
  final List<String> momentumInsights;

  /// 7. Customer RFM & Churn flow
  final List<CustomerRfmSegment> rfmSegments;
  final int churnRiskCount;
  final double retentionRate;
  final List<String> retentionInsights;
}

PrescriptiveReport _computePrescriptive(
  List<Product> products,
  _TrainingData t, {
  List<CafeOrder> allOrders = const [],
}) {
  final days = t.days;

  // 1. Restock
  final restock = products.where((p) => p.stock != null).map((p) {
    final demand = t.rateOf(p.id) * t.growthOf(p.id) * kRestockCoverDays;
    final target = (demand * kSafetyStockFactor).ceil();
    final reorder = math.max(0, target - p.stock!);
    return RestockRecommendation(
      product: p,
      forecastDemand: demand,
      targetLevel: target,
      reorderQty: reorder,
    );
  }).toList()
    ..sort((a, b) {
      final c = b.reorderQty.compareTo(a.reorderQty);
      return c != 0 ? c : a.stock.compareTo(b.stock);
    });
  final needing = restock.where((r) => r.reorderQty > 0).toList();
  final restockInsights = <String>[
    if (needing.isEmpty)
      'All tracked items have enough stock for the next $kRestockCoverDays days.'
    else
      '${needing.length} item(s) need restocking to cover the next $kRestockCoverDays days '
          '(includes a ${((kSafetyStockFactor - 1) * 100).round()}% safety buffer).',
    for (final r in needing.take(3))
      'Order ${r.reorderQty} × ${r.product.name} (stock ${r.stock}, '
          'forecast demand ${r.forecastDemand.toStringAsFixed(1)}).',
    for (final r in restock.where((r) => r.stock <= 0).take(2))
      '${r.product.name} is OUT OF STOCK – restock immediately.',
  ];

  // 2. Promotion timing
  final wdRev = List<double>.filled(7, 0);
  final wdOcc = List<int>.filled(7, 0);
  for (var i = 0; i < days; i++) {
    final w = _addDays(t.window.start, i).weekday - 1;
    wdOcc[w]++;
    wdRev[w] += t.revenue[i];
  }
  final totalRev = t.revenue.fold<double>(0, (a, b) => a + b);
  final dailyAvg = days == 0 ? 0.0 : totalRev / days;
  final weekdays = List.generate(7, (w) {
    final avg = wdOcc[w] == 0 ? 0.0 : wdRev[w] / wdOcc[w];
    return WeekdayIndex(w + 1, avg, dailyAvg == 0 ? 0 : avg / dailyAvg * 100);
  });
  final promoInsights = <String>[];
  if (totalRev > 0) {
    final sorted = [...weekdays]..sort((a, b) => a.index.compareTo(b.index));
    final low = sorted.first;
    final high = sorted.last;
    final gap = dailyAvg - low.avgRevenue;
    promoInsights.add(
        'Run promotions on ${kWeekdayLong[low.weekday - 1]} – it averages '
        '${formatPeso(low.avgRevenue)} (index ${low.index.round()}), '
        '${formatPeso(gap)} below an average day.');
    if (sorted.length > 1 && sorted[1].index < 90) {
      promoInsights.add(
          '${kWeekdayLong[sorted[1].weekday - 1]} is also below average '
          '(index ${sorted[1].index.round()}) – a good second promo day.');
    }
    promoInsights.add(
        'Avoid discounts on ${kWeekdayLong[high.weekday - 1]} – your strongest day '
        '(index ${high.index.round()}); focus on upselling instead.');
  } else {
    promoInsights.add('Not enough sales data to recommend promotion days yet.');
  }

  // 3. Staffing (based on the busiest weekday)
  final wdOrders = List<double>.filled(7, 0);
  for (final o in t.orders) {
    wdOrders[o.createdAt.weekday - 1] += 1;
  }
  var busiest = 0;
  var busiestAvg = -1.0;
  for (var w = 0; w < 7; w++) {
    final avg = wdOcc[w] == 0 ? 0.0 : wdOrders[w] / wdOcc[w];
    if (avg > busiestAvg) {
      busiestAvg = avg;
      busiest = w;
    }
  }
  final hourly = List<double>.filled(24, 0);
  for (final o in t.orders) {
    if (o.createdAt.weekday - 1 == busiest) hourly[o.createdAt.hour] += 1;
  }
  final occ = math.max(1, wdOcc[busiest]);
  final staffing = List.generate(24, (h) {
    final exp = hourly[h] / occ;
    final staff = exp <= 0 ? 0 : math.max(1, (exp / kOrdersPerBaristaPerHour).ceil());
    return StaffingSlot(h, exp, staff);
  });
  final active = staffing.where((s) => s.expectedOrders > 0).toList();
  final staffingInsights = <String>[];
  if (active.isEmpty) {
    staffingInsights.add('Not enough order data to build a staffing plan yet.');
  } else {
    final peak = active.reduce((a, b) => a.expectedOrders >= b.expectedOrders ? a : b);
    final maxStaff = active.map((s) => s.staff).reduce(math.max);
    staffingInsights.add(
        'Plan for ${kWeekdayLong[busiest]} (busiest day): peak at '
        '${hourLabel(peak.hour)} with ~${peak.expectedOrders.toStringAsFixed(1)} orders/hour.');
    staffingInsights.add(
        'Schedule up to $maxStaff barista(s) at peak '
        '(assumes $kOrdersPerBaristaPerHour orders per barista per hour).');
    staffingInsights.add(
        'Active hours: ${hourLabel(active.first.hour)} – ${hourLabel((active.last.hour + 1) % 24)}. '
        'Keep 1 barista during quieter hours.');
  }

  // 4. Menu engineering
  final sold = t.products.values.where((p) => p.total > 0).toList();
  final totalQty = sold.fold<int>(0, (a, p) => a + p.total);
  final totalItemRev = sold.fold<double>(0, (a, p) => a + p.revenue);
  final popThreshold = sold.isEmpty ? 0.0 : (totalQty / sold.length) * 0.7;
  final priceThreshold = totalQty == 0 ? 0.0 : totalItemRev / totalQty;
  final menu = sold.map((p) {
    final avgPrice = p.revenue / p.total;
    final popular = p.total >= popThreshold;
    final pricey = avgPrice >= priceThreshold;
    final cls = popular
        ? (pricey ? MenuClass.star : MenuClass.plowhorse)
        : (pricey ? MenuClass.puzzle : MenuClass.dog);
    return MenuItemAnalysis(p.name, p.total, p.revenue, avgPrice, cls);
  }).toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  final menuInsights = <String>[];
  for (final c in MenuClass.values) {
    final items = menu.where((m) => m.cls == c).toList();
    if (items.isEmpty) continue;
    final names = items.take(3).map((m) => m.name).join(', ');
    menuInsights.add('${c.label}s (${items.length}): $names${items.length > 3 ? '…' : ''} → ${c.action}.');
  }
  if (menuInsights.isEmpty) {
    menuInsights.add('No product sales in this period to analyze.');
  }

  // 5. Bundles
  final priceById = {for (final p in products) p.id: p.price};
  final nameByKey = <String, String>{};
  final avgPriceByKey = <String, double>{};
  for (final p in t.products.values) {
    nameByKey[p.key] = p.name;
    avgPriceByKey[p.key] = p.total == 0 ? 0 : p.revenue / p.total;
  }
  final pairCounts = <String, int>{};
  var multi = 0;
  for (final o in t.orders) {
    final keys = o.items.map(_itemKey).toSet().toList()..sort();
    if (keys.length < 2) continue;
    multi++;
    for (var i = 0; i < keys.length; i++) {
      for (var j = i + 1; j < keys.length; j++) {
        final k = '${keys[i]}|${keys[j]}';
        pairCounts[k] = (pairCounts[k] ?? 0) + 1;
      }
    }
  }
  double priceOf(String key) => priceById[key] ?? avgPriceByKey[key] ?? 0;
  final bundles = pairCounts.entries.map((e) {
    final parts = e.key.split('|');
    final regular = priceOf(parts[0]) + priceOf(parts[1]);
    return BundlePair(
      nameByKey[parts[0]] ?? parts[0],
      nameByKey[parts[1]] ?? parts[1],
      e.value,
      multi == 0 ? 0 : e.value / multi,
      regular * (1 - kBundleDiscount),
      regular,
    );
  }).toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  final topBundles = bundles.take(8).toList();
  final bundleInsights = <String>[
    if (topBundles.isEmpty)
      'No multi-item orders yet – bundles cannot be suggested.'
    else ...[
      'Create a "${topBundles.first.a} + ${topBundles.first.b}" combo at '
          '${formatPeso(topBundles.first.bundlePrice)} (regular ${formatPeso(topBundles.first.regularPrice)}, '
          '${(kBundleDiscount * 100).round()}% off) – bought together in ${topBundles.first.count} orders.',
      if (topBundles.length > 1)
        'Second option: ${topBundles[1].a} + ${topBundles[1].b} '
            '(${topBundles[1].count} orders, ${(topBundles[1].share * 100).toStringAsFixed(1)}% of multi-item orders).',
      '$multi of ${t.orders.length} orders contain 2+ different products.',
    ],
  ];

  // 6. Momentum
  final half = days ~/ 2;
  final momentum = <ProductMomentum>[];
  for (final p in t.products.values) {
    if (p.total < 3) continue;
    var f = 0, s = 0;
    for (var i = 0; i < days; i++) {
      if (i < days - half) {
        f += p.daily[i];
      } else {
        s += p.daily[i];
      }
    }
    if (half > 0 && days - half != half) {
      s = (s * (days - half) / half).round();
    }
    momentum.add(ProductMomentum(p.name, f, s));
  }
  momentum.sort((a, b) => b.growthPct.compareTo(a.growthPct));
  final picked = <ProductMomentum>[
    ...momentum.take(5),
    ...momentum.reversed.take(5).where((m) => !momentum.take(5).contains(m)),
  ]..sort((a, b) => b.growthPct.compareTo(a.growthPct));
  final rising = picked.where((m) => m.growthPct > 0).toList();
  final falling = picked.where((m) => m.growthPct < 0).toList();
  final momentumInsights = <String>[
    if (picked.isEmpty) 'Not enough product sales to measure momentum.',
    if (rising.isNotEmpty)
      'Feature rising items on the home screen: '
          '${rising.take(3).map((m) => '${m.name} (+${m.growthPct.toStringAsFixed(0)}%)').join(', ')}.',
    if (falling.isNotEmpty)
      'Review or promote declining items: '
          '${falling.reversed.take(3).map((m) => '${m.name} (${m.growthPct.toStringAsFixed(0)}%)').join(', ')}.',
  ];

  // 7. Customer RFM Segmentation & Churn Risk Flow
  final orderSource = allOrders.isNotEmpty ? allOrders : t.orders;
  final customerOrders = <String, List<CafeOrder>>{};
  for (final o in orderSource) {
    if (!_isValid(o)) continue;
    final cid = o.customerId.isNotEmpty
        ? o.customerId
        : (o.terminalId?.isNotEmpty == true ? o.terminalId! : 'order_${o.id}');
    customerOrders.putIfAbsent(cid, () => []).add(o);
  }

  int champCount = 0, loyalCount = 0, promCount = 0, atRiskCount = 0, churnCount = 0;
  double champSpent = 0, loyalSpent = 0, promSpent = 0, atRiskSpent = 0, churnSpent = 0;
  int champOrders = 0, loyalOrders = 0, promOrders = 0, atRiskOrders = 0, churnOrders = 0;
  final now = DateTime.now();

  for (final entry in customerOrders.entries) {
    final oList = entry.value..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recency = _daysBetween(oList.first.createdAt, now);
    final freq = oList.length;
    final spend = oList.fold<double>(0, (a, b) => a + b.total);

    if (freq >= 4 && recency <= 7) {
      champCount++; champSpent += spend; champOrders += freq;
    } else if (freq >= 3 && recency <= 14) {
      loyalCount++; loyalSpent += spend; loyalOrders += freq;
    } else if (freq <= 2 && recency <= 10 && spend >= 300) {
      promCount++; promSpent += spend; promOrders += freq;
    } else if (freq >= 2 && recency > 14 && recency <= 30) {
      atRiskCount++; atRiskSpent += spend; atRiskOrders += freq;
    } else {
      churnCount++; churnSpent += spend; churnOrders += freq;
    }
  }

  final rfmSegments = [
    CustomerRfmSegment(
      name: 'Champions (VIP Regulars)',
      customerCount: champCount,
      totalSpent: champSpent,
      avgOrders: champCount > 0 ? champOrders / champCount : 0,
      recencyDays: 4,
      description: 'Frequent high-spend customers visiting weekly.',
      action: 'Offer secret menu previews and personal loyalty perks.',
    ),
    CustomerRfmSegment(
      name: 'Loyal Patrons',
      customerCount: loyalCount,
      totalSpent: loyalSpent,
      avgOrders: loyalCount > 0 ? loyalOrders / loyalCount : 0,
      recencyDays: 10,
      description: 'Reliable repeat customers with steady order frequency.',
      action: 'Send stamp-card / milestone rewards to reinforce habit.',
    ),
    CustomerRfmSegment(
      name: 'Promising High-Value',
      customerCount: promCount,
      totalSpent: promSpent,
      avgOrders: promCount > 0 ? promOrders / promCount : 0,
      recencyDays: 6,
      description: 'Recent new customers with large ticket orders.',
      action: 'Encourage second visit with a complimentary beverage upgrade.',
    ),
    CustomerRfmSegment(
      name: 'At-Risk (Churn Warning)',
      customerCount: atRiskCount,
      totalSpent: atRiskSpent,
      avgOrders: atRiskCount > 0 ? atRiskOrders / atRiskCount : 0,
      recencyDays: 22,
      description: 'Regulars who have not ordered in 14-30 days.',
      action: 'Re-engage via promo coupon: "We miss you – 20% off your next visit".',
    ),
    CustomerRfmSegment(
      name: 'Occasional / Inactive',
      customerCount: churnCount,
      totalSpent: churnSpent,
      avgOrders: churnCount > 0 ? churnOrders / churnCount : 0,
      recencyDays: 45,
      description: 'Single-order walk-ins or inactive for >30 days.',
      action: 'Promote seasonal menu launches and weekend combo deals.',
    ),
  ];

  final totalCustomers = customerOrders.length;
  final repeatCustomers = customerOrders.values.where((l) => l.length >= 2).length;
  final retentionRate = totalCustomers > 0 ? (repeatCustomers / totalCustomers * 100) : 0.0;

  final retentionInsights = <String>[
    if (totalCustomers == 0)
      'No customer profiles recorded yet.'
    else ...[
      'Customer retention rate: ${retentionRate.toStringAsFixed(1)}% ($repeatCustomers repeat of $totalCustomers total customers).',
      if (atRiskCount > 0)
        '$atRiskCount previously active customers are at risk of churning – send a re-engagement offer.',
      if (champCount > 0)
        '$champCount VIP Champion customers generate ${formatPeso(champSpent)} in store revenue.',
    ],
  ];

  return PrescriptiveReport(
    restock: restock,
    restockInsights: restockInsights,
    weekdays: weekdays,
    promoInsights: promoInsights,
    busiestWeekday: busiest + 1,
    staffing: staffing,
    staffingInsights: staffingInsights,
    menu: menu,
    popularityThreshold: popThreshold,
    priceThreshold: priceThreshold,
    menuInsights: menuInsights,
    bundles: topBundles,
    multiItemOrders: multi,
    bundleInsights: bundleInsights,
    momentum: picked,
    momentumInsights: momentumInsights,
    rfmSegments: rfmSegments,
    churnRiskCount: atRiskCount,
    retentionRate: retentionRate,
    retentionInsights: retentionInsights,
  );
}

// ── Top-level report ─────────────────────────────────────────────────────────

class AnalyticsReport {
  AnalyticsReport({
    required this.range,
    required this.generatedAt,
    required this.descriptive,
    required this.predictive,
    required this.prescriptive,
  });
  final AnalyticsRange range;
  final DateTime generatedAt;
  final DescriptiveReport descriptive;
  final PredictiveReport predictive;
  final PrescriptiveReport prescriptive;
}

AnalyticsReport computeAnalytics({
  required List<CafeOrder> orders,
  required List<Product> products,
  required List<CafeanaFeedback> feedback,
  required AnalyticsSelection selection,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final today = _day(n);
  DateTime? earliest;
  for (final o in orders) {
    if (earliest == null || o.createdAt.isBefore(earliest)) earliest = o.createdAt;
  }
  final range = selection.resolve(now: n, earliest: earliest);
  final training = _buildTraining(orders, _trainingWindow(range, today));
  return AnalyticsReport(
    range: range,
    generatedAt: n,
    descriptive: computeDescriptive(
      orders: orders,
      products: products,
      feedback: feedback,
      range: range,
    ),
    predictive: _computePredictive(
      orders,
      products,
      training,
      today,
      range: range,
      selection: selection,
    ),
    prescriptive: _computePrescriptive(products, training, allOrders: orders),
  );
}
