import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/widgets/animated_glass_card.dart';

typedef ValueFormatter = String Function(double v);

/// Curated palette used across analytics charts.
const List<Color> kChartPalette = [
  Color(0xFF8D5B3E), // coffee
  Color(0xFFE0A458), // caramel
  Color(0xFF4F9D8A), // matcha
  Color(0xFF5B7DB1), // blueberry
  Color(0xFFC8553D), // cinnamon
  Color(0xFF9B6FB0), // taro
  Color(0xFF6C9A3B), // pistachio
  Color(0xFFD98BA0), // strawberry
  Color(0xFF3E6E8E), // ocean
  Color(0xFFB08D57), // mocha
];

const Color kGood = Color(0xFF2E9E6A);
const Color kWarn = Color(0xFFE39B2D);
const Color kBad = Color(0xFFD64545);
const Color kForecast = Color(0xFF8E5BD8);

double _niceMax(double v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final f = v / exp;
  final nice = f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10;
  return nice * exp;
}

int _labelStep(int n, double width, {double minPx = 46}) {
  final maxLabels = math.max(2, (width / minPx).floor());
  return math.max(1, (n / maxLabels).ceil());
}

TextStyle _axisStyle(BuildContext c) => TextStyle(
      fontSize: 10,
      color: Theme.of(c).colorScheme.onSurfaceVariant,
    );

FlTitlesData _titles(
  BuildContext context, {
  required List<String> labels,
  required ValueFormatter leftFmt,
  required double width,
  double maxY = 0,
  double leftReserved = 58,
}) {
  final step = _labelStep(labels.length, width - leftReserved);
  return FlTitlesData(
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: leftReserved,
        interval: maxY > 0 ? maxY / 4 : null,
        getTitlesWidget: (v, meta) => SideTitleWidget(
          meta: meta,
          fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
          child: Text(leftFmt(v), style: _axisStyle(context)),
        ),
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 32,
        interval: 1,
        getTitlesWidget: (v, meta) {
          final i = v.round();
          if ((v - i).abs() > 0.01 || i < 0 || i >= labels.length || i % step != 0) {
            return const SizedBox.shrink();
          }
          return SideTitleWidget(
            meta: meta,
            fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0),
            child: Text(labels[i], style: _axisStyle(context)),
          );
        },
      ),
    ),
  );
}

FlGridData _grid(BuildContext c, double maxY) => FlGridData(
      show: true,
      drawVerticalLine: false,
      horizontalInterval: maxY > 0 ? maxY / 4 : null,
      getDrawingHorizontalLine: (_) => FlLine(
        color: Theme.of(c).colorScheme.outlineVariant.withValues(alpha: 0.35),
        strokeWidth: 1,
        dashArray: [4, 4],
      ),
    );

Color _tooltipBg(BuildContext c) =>
    Theme.of(c).colorScheme.inverseSurface.withValues(alpha: 0.92);
TextStyle _tooltipText(BuildContext c) => TextStyle(
      color: Theme.of(c).colorScheme.onInverseSurface,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

Widget emptyChart(BuildContext context, [String msg = 'No data for this period']) =>
    Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_outlined,
              size: 36, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text(msg, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
        ],
      ),
    );

// ── Card wrapper ─────────────────────────────────────────────────────────────

class LegendEntry {
  const LegendEntry(this.label, this.color, {this.dashed = false});
  final String label;
  final Color color;
  final bool dashed;
}

class AnalyticsChartCard extends StatelessWidget {
  const AnalyticsChartCard({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.child,
    this.height = 240,
    this.legend = const [],
    this.insights = const [],
    this.accent,
    this.headline,
  });

  final String index;
  final String title;
  final String subtitle;
  final Widget child;
  final double? height;
  final List<LegendEntry> legend;
  final List<String> insights;
  final Color? accent;

  /// Optional big number shown at the top-right of the card.
  final String? headline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = accent ?? cs.primary;
    return AnimatedGlassCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(index,
                    style: TextStyle(
                        color: color, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              if (headline != null) ...[
                const SizedBox(width: 8),
                Text(headline!,
                    style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800, color: color)),
              ],
            ],
          ),
          const SizedBox(height: 18),
          if (height != null) SizedBox(height: height, child: child) else child,
          if (legend.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                for (final l in legend)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 12,
                      height: l.dashed ? 3 : 12,
                      decoration: BoxDecoration(
                        color: l.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(l.label, style: theme.textTheme.bodySmall),
                  ]),
              ],
            ),
          ],
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in insights)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.auto_awesome, size: 14, color: color),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(s, style: theme.textTheme.bodySmall)),
                        ],
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

// ── Line chart ───────────────────────────────────────────────────────────────

class LineSeries {
  const LineSeries(this.name, this.values, this.color, {this.dashed = false, this.fill = true});
  final String name;
  final List<double?> values; // null = gap
  final Color color;
  final bool dashed;
  final bool fill;
}

class TrendLineChart extends StatelessWidget {
  const TrendLineChart({
    super.key,
    required this.labels,
    required this.series,
    required this.axisFmt,
    required this.tooltipFmt,
    this.tooltipLabels,
    this.bandLower,
    this.bandUpper,
    this.bandColor,
  });

  final List<String> labels;
  final List<String>? tooltipLabels;
  final List<LineSeries> series;
  final ValueFormatter axisFmt;
  final ValueFormatter tooltipFmt;
  final List<double?>? bandLower;
  final List<double?>? bandUpper;
  final Color? bandColor;

  @override
  Widget build(BuildContext context) {
    final all = [
      for (final s in series) ...s.values.whereType<double>(),
      ...?bandUpper?.whereType<double>(),
    ];
    if (all.isEmpty || all.every((v) => v == 0)) return emptyChart(context);
    final maxY = _niceMax(all.reduce(math.max) * 1.15);

    List<FlSpot> spots(List<double?> v) => [
          for (var i = 0; i < v.length; i++)
            v[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), v[i]!)
        ];

    final bars = <LineChartBarData>[
      for (final s in series)
        LineChartBarData(
          spots: spots(s.values),
          isCurved: true,
          preventCurveOverShooting: true,
          color: s.color,
          barWidth: 3,
          dashArray: s.dashed ? [6, 4] : null,
          isStrokeCapRound: true,
          dotData: FlDotData(show: s.values.length <= 31),
          belowBarData: BarAreaData(
            show: s.fill,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [s.color.withValues(alpha: 0.28), s.color.withValues(alpha: 0.0)],
            ),
          ),
        ),
    ];
    final betweens = <BetweenBarsData>[];
    if (bandLower != null && bandUpper != null) {
      final c = bandColor ?? kForecast;
      bars.add(LineChartBarData(
          spots: spots(bandUpper!), color: Colors.transparent, barWidth: 0,
          dotData: const FlDotData(show: false), isCurved: true, preventCurveOverShooting: true));
      bars.add(LineChartBarData(
          spots: spots(bandLower!), color: Colors.transparent, barWidth: 0,
          dotData: const FlDotData(show: false), isCurved: true, preventCurveOverShooting: true));
      betweens.add(BetweenBarsData(
          fromIndex: bars.length - 2, toIndex: bars.length - 1,
          color: c.withValues(alpha: 0.12)));
    }

    return LayoutBuilder(builder: (context, box) {
      return LineChart(
        LineChartData(
          clipData: const FlClipData.none(),
          minY: 0,
          maxY: maxY,
          minX: 0,
          maxX: math.max(1, labels.length - 1).toDouble(),
          lineBarsData: bars,
          betweenBarsData: betweens,
          titlesData: _titles(context,
              labels: labels, leftFmt: axisFmt, width: box.maxWidth, maxY: maxY),
          gridData: _grid(context, maxY),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => _tooltipBg(context),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) {
                return spots.map((s) {
                  if (s.barIndex >= series.length) return null;
                  final i = s.x.round();
                  final ser = series[s.barIndex];
                  final header = s == spots.first
                      ? '${(tooltipLabels ?? labels)[i]}\n'
                      : '';
                  return LineTooltipItem(
                    '$header${ser.name}: ${tooltipFmt(s.y)}',
                    _tooltipText(context).copyWith(color: ser.color.withValues(alpha: 1)),
                  );
                }).toList();
              },
            ),
          ),
        ),
      );
    });
  }
}

// ── Vertical bar chart ───────────────────────────────────────────────────────

class BarSeries {
  const BarSeries(this.name, this.values, this.color);
  final String name;
  final List<double> values;
  final Color color;
}

class ValueBarChart extends StatelessWidget {
  const ValueBarChart({
    super.key,
    required this.labels,
    required this.series,
    required this.axisFmt,
    required this.tooltipFmt,
    this.tooltipLabels,
    this.colorFor,
    this.stacked = false,
    this.referenceLine,
    this.referenceLabel,
  });

  final List<String> labels;
  final List<String>? tooltipLabels;
  final List<BarSeries> series;
  final ValueFormatter axisFmt;
  final ValueFormatter tooltipFmt;

  /// Overrides the colour of single-series bars per index.
  final Color Function(int index, double value)? colorFor;
  final bool stacked;
  final double? referenceLine;
  final String? referenceLabel;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    double maxV = 0;
    for (var i = 0; i < n; i++) {
      if (stacked) {
        maxV = math.max(maxV, series.fold(0.0, (a, s) => a + s.values[i]));
      } else {
        for (final s in series) {
          maxV = math.max(maxV, s.values[i]);
        }
      }
    }
    if (referenceLine != null) maxV = math.max(maxV, referenceLine!);
    if (maxV <= 0) return emptyChart(context);
    final maxY = _niceMax(maxV * 1.08);

    return LayoutBuilder(builder: (context, box) {
      final groupW = (box.maxWidth - 60) / math.max(1, n);
      final rodW = stacked || series.length == 1
          ? (groupW * 0.62).clamp(3.0, 28.0)
          : ((groupW * 0.8) / series.length).clamp(2.0, 16.0);
      final radius = BorderRadius.vertical(top: Radius.circular(math.min(6, rodW / 2)));

      final groups = List.generate(n, (i) {
        if (stacked) {
          double acc = 0;
          final items = <BarChartRodStackItem>[];
          for (final s in series) {
            items.add(BarChartRodStackItem(acc, acc + s.values[i], s.color));
            acc += s.values[i];
          }
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
                toY: acc, width: rodW, rodStackItems: items,
                color: Colors.transparent, borderRadius: radius),
          ]);
        }
        return BarChartGroupData(
          x: i,
          barsSpace: 2,
          barRods: [
            for (final s in series)
              BarChartRodData(
                toY: s.values[i],
                width: rodW,
                borderRadius: radius,
                color: series.length == 1 && colorFor != null
                    ? colorFor!(i, s.values[i])
                    : s.color,
                backDrawRodData: BackgroundBarChartRodData(
                  show: series.length == 1,
                  toY: maxY,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.35),
                ),
              ),
          ],
        );
      });

      return BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          barGroups: groups,
          titlesData: _titles(context,
              labels: labels, leftFmt: axisFmt, width: box.maxWidth, maxY: maxY),
          gridData: _grid(context, maxY),
          borderData: FlBorderData(show: false),
          extraLinesData: referenceLine == null
              ? null
              : ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                    y: referenceLine!,
                    color: Theme.of(context).colorScheme.outline,
                    strokeWidth: 1.5,
                    dashArray: [6, 4],
                    label: HorizontalLineLabel(
                      show: referenceLabel != null,
                      alignment: Alignment.topRight,
                      labelResolver: (_) => referenceLabel ?? '',
                      style: _axisStyle(context).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ]),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _tooltipBg(context),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, gi, rod, ri) {
                final title = (tooltipLabels ?? labels)[group.x];
                final lines = stacked
                    ? series.map((s) => '${s.name}: ${tooltipFmt(s.values[group.x])}').join('\n')
                    : '${series[ri].name}: ${tooltipFmt(rod.toY)}';
                return BarTooltipItem('$title\n$lines', _tooltipText(context));
              },
            ),
          ),
        ),
      );
    });
  }
}

// ── Horizontal bar chart (great for long product names) ─────────────────────

class HBarItem {
  const HBarItem(this.label, this.value, this.display, {this.color, this.secondary, this.secondaryColor, this.caption});
  final String label;
  final double value;
  final String display;
  final Color? color;

  /// Optional overlay marker value (e.g. target level).
  final double? secondary;
  final Color? secondaryColor;
  final String? caption;
}

class HBarChart extends StatelessWidget {
  const HBarChart({super.key, required this.items, this.maxValue, this.diverging = false});
  final List<HBarItem> items;
  final double? maxValue;

  /// When true, negative values extend left from a centre axis.
  final bool diverging;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SizedBox(height: 140, child: emptyChart(context));
    }
    final cs = Theme.of(context).colorScheme;
    final maxV = maxValue ??
        items
            .map((e) => math.max(e.value.abs(), e.secondary ?? 0))
            .fold<double>(0, math.max);
    final denom = maxV <= 0 ? 1.0 : maxV;

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _HBarRow(
              item: items[i],
              fraction: (items[i].value.abs() / denom).clamp(0.0, 1.0),
              secondaryFraction: items[i].secondary == null
                  ? null
                  : (items[i].secondary! / denom).clamp(0.0, 1.0),
              color: items[i].color ?? kChartPalette[i % kChartPalette.length],
              track: cs.surfaceContainerHighest.withValues(alpha: 0.55),
              diverging: diverging,
              negative: items[i].value < 0,
              delay: i * 60,
            ),
          ),
      ],
    );
  }
}

class _HBarRow extends StatelessWidget {
  const _HBarRow({
    required this.item,
    required this.fraction,
    required this.secondaryFraction,
    required this.color,
    required this.track,
    required this.diverging,
    required this.negative,
    required this.delay,
  });
  final HBarItem item;
  final double fraction;
  final double? secondaryFraction;
  final Color color;
  final Color track;
  final bool diverging;
  final bool negative;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: '${item.label}: ${item.display}${item.caption != null ? '\n${item.caption}' : ''}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Text(item.display,
                style: theme.textTheme.bodySmall
                    ?.copyWith(fontWeight: FontWeight.w800, color: color)),
          ]),
          if (item.caption != null)
            Text(item.caption!,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            final half = w / 2;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: Duration(milliseconds: 700 + delay),
              curve: Curves.easeOutCubic,
              builder: (context, f, _) {
                final barW = diverging ? half * f : w * f;
                final left = diverging ? (negative ? half - barW : half) : 0.0;
                return SizedBox(
                  height: 12,
                  child: Stack(children: [
                    Container(
                        decoration: BoxDecoration(
                            color: track, borderRadius: BorderRadius.circular(6))),
                    Positioned(
                      left: left,
                      width: barW,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            color.withValues(alpha: 0.75),
                            color,
                          ]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    if (diverging)
                      Positioned(
                        left: half - 1,
                        width: 2,
                        top: 0,
                        bottom: 0,
                        child: Container(color: theme.colorScheme.outline),
                      ),
                    if (secondaryFraction != null)
                      Positioned(
                        left: (w * secondaryFraction!).clamp(0, w - 3),
                        width: 3,
                        top: -2,
                        bottom: -2,
                        child: Container(
                          decoration: BoxDecoration(
                            color: item.secondaryColor ?? theme.colorScheme.onSurface,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ]),
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

// ── Donut chart ──────────────────────────────────────────────────────────────

class DonutSlice {
  const DonutSlice(this.label, this.value, this.color, {this.display});
  final String label;
  final double value;
  final Color color;
  final String? display;
}

class DonutChart extends StatefulWidget {
  const DonutChart({super.key, required this.slices, this.centerTitle, this.centerValue});
  final List<DonutSlice> slices;
  final String? centerTitle;
  final String? centerValue;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices.where((s) => s.value > 0).toList();
    final total = slices.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return emptyChart(context);
    final theme = Theme.of(context);

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > 360;
      final chart = Stack(alignment: Alignment.center, children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 52,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(touchCallback: (e, r) {
              setState(() {
                _touched = (!e.isInterestedForInteractions || r?.touchedSection == null)
                    ? -1
                    : r!.touchedSection!.touchedSectionIndex;
              });
            }),
            sections: [
              for (var i = 0; i < slices.length; i++)
                PieChartSectionData(
                  value: slices[i].value,
                  color: slices[i].color,
                  radius: i == _touched ? 40 : 32,
                  title: slices[i].value / total >= 0.07
                      ? '${(slices[i].value / total * 100).toStringAsFixed(0)}%'
                      : '',
                  titleStyle: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            _touched >= 0 && _touched < slices.length
                ? (slices[_touched].display ?? slices[_touched].value.toStringAsFixed(0))
                : (widget.centerValue ?? total.toStringAsFixed(0)),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            _touched >= 0 && _touched < slices.length
                ? slices[_touched].label
                : (widget.centerTitle ?? 'Total'),
            style: theme.textTheme.labelSmall,
          ),
        ]),
      ]);

      final legend = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in slices.take(8))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${s.label} · ${s.display ?? s.value.toStringAsFixed(0)}',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ]),
            ),
        ],
      );

      if (wide) {
        return Row(children: [
          Expanded(flex: 5, child: chart),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: legend),
        ]);
      }
      return Column(children: [
        Expanded(child: chart),
        const SizedBox(height: 8),
        SizedBox(height: 70, child: SingleChildScrollView(child: legend)),
      ]);
    });
  }
}

// ── Quadrant scatter chart (menu engineering) ───────────────────────────────

class ScatterPoint {
  const ScatterPoint(this.label, this.x, this.y, this.color, this.detail);
  final String label;
  final double x;
  final double y;
  final Color color;
  final String detail;
}

class QuadrantScatterChart extends StatelessWidget {
  const QuadrantScatterChart({
    super.key,
    required this.points,
    required this.xThreshold,
    required this.yThreshold,
    required this.xFmt,
    required this.yFmt,
    required this.quadrantLabels, // TL, TR, BL, BR
  });
  final List<ScatterPoint> points;
  final double xThreshold;
  final double yThreshold;
  final ValueFormatter xFmt;
  final ValueFormatter yFmt;
  final List<String> quadrantLabels;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return emptyChart(context);
    final maxX = _niceMax(math.max(xThreshold, points.map((p) => p.x).reduce(math.max)) * 1.1);
    final maxY = _niceMax(math.max(yThreshold, points.map((p) => p.y).reduce(math.max)) * 1.1);
    final ql = _axisStyle(context).copyWith(fontWeight: FontWeight.w800, fontSize: 11);

    return Stack(children: [
      ScatterChart(
        ScatterChartData(
          minX: 0,
          maxX: maxX,
          minY: 0,
          maxY: maxY,
          scatterSpots: [
            for (final p in points)
              ScatterSpot(p.x, p.y,
                  dotPainter: FlDotCirclePainter(
                      radius: 8,
                      color: p.color.withValues(alpha: 0.85),
                      strokeColor: Colors.white,
                      strokeWidth: 1.5)),
          ],
          gridData: _grid(context, maxY),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              axisNameWidget: Text('Avg price', style: _axisStyle(context)),
              sideTitles: SideTitles(
                showTitles: true, reservedSize: 44, interval: maxY / 4,
                getTitlesWidget: (v, m) => SideTitleWidget(
                    meta: m, child: Text(yFmt(v), style: _axisStyle(context))),
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text('Units sold (popularity)', style: _axisStyle(context)),
              sideTitles: SideTitles(
                showTitles: true, reservedSize: 24, interval: maxX / 4,
                getTitlesWidget: (v, m) => SideTitleWidget(
                    meta: m, child: Text(xFmt(v), style: _axisStyle(context))),
              ),
            ),
          ),

          scatterTouchData: ScatterTouchData(
            enabled: true,
            touchTooltipData: ScatterTouchTooltipData(
              getTooltipColor: (_) => _tooltipBg(context),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spot) {
                final p = points.firstWhere(
                    (e) => e.x == spot.x && e.y == spot.y,
                    orElse: () => points.first);
                return ScatterTooltipItem('${p.label}\n${p.detail}',
                    textStyle: _tooltipText(context));
              },
            ),
          ),
        ),
      ),
      Positioned(left: 56, top: 2, child: Text(quadrantLabels[0], style: ql)),
      Positioned(right: 6, top: 2, child: Text(quadrantLabels[1], style: ql)),
      Positioned(left: 56, bottom: 44, child: Text(quadrantLabels[2], style: ql)),
      Positioned(right: 6, bottom: 44, child: Text(quadrantLabels[3], style: ql)),
    ]);
  }
}
