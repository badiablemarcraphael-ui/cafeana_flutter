import 'package:flutter_test/flutter_test.dart';
import 'package:cafeana_app/core/analytics/analytics_engine.dart';
import 'package:cafeana_app/core/models/order.dart';
import 'package:cafeana_app/core/models/product.dart';
import 'package:cafeana_app/core/models/feedback_model.dart';
import 'package:cafeana_app/core/utils/export_csv_util.dart';

void main() {
  group('Machine Learning & Analytics Engine Tests', () {
    test('computes precision ML ensemble, cash flow, queue flow, and RFM segments', () {
      final now = DateTime(2026, 10, 20, 14, 0);
      final products = [
        const Product(
          id: 'p1',
          name: 'Spanish Latte',
          price: 150.0,
          category: 'coffee',
          isAvailable: true,
          stock: 45,
        ),
        const Product(
          id: 'p2',
          name: 'Matcha Espresso',
          price: 175.0,
          category: 'matcha',
          isAvailable: true,
          stock: 8,
        ),
      ];

      final orders = <CafeOrder>[];
      // Generate 21 days of synthetic historical orders with weekday variance
      for (var day = 0; day < 21; day++) {
        final orderDate = now.subtract(Duration(days: 20 - day));
        final isWeekend = orderDate.weekday == DateTime.saturday || orderDate.weekday == DateTime.sunday;
        final count = isWeekend ? 8 : 4;

        for (var i = 0; i < count; i++) {
          final custId = 'user_${i % 4}';
          orders.add(CafeOrder(
            id: 'ord_${day}_$i',
            orderNumber: day * 100 + i,
            customerId: custId,
            items: [
              const OrderItem(
                productId: 'p1',
                name: 'Spanish Latte',
                quantity: 2,
                price: 150.0,
              ),
              if (i % 2 == 0)
                const OrderItem(
                  productId: 'p2',
                  name: 'Matcha Espresso',
                  quantity: 1,
                  price: 175.0,
                ),
            ],
            total: i % 2 == 0 ? 475.0 : 300.0,
            paymentStatus: PaymentStatus.paid,
            status: OrderStatus.completed,
            createdAt: orderDate.add(Duration(hours: 8 + (i * 2))),
            updatedAt: orderDate.add(Duration(hours: 8 + (i * 2))),
          ));
        }
      }

      final report = computeAnalytics(
        orders: orders,
        products: products,
        feedback: <CafeanaFeedback>[],
        selection: const AnalyticsSelection(AnalyticsPreset.last30Days),
        now: now,
      );

      // Verify ML Model scorecard
      expect(report.predictive.modelScores.length, 3);
      expect(report.predictive.revenue.model.accuracy, greaterThan(0.0));
      expect(report.predictive.revenue.model.residualStd, greaterThan(0.0));

      // Verify 14-day cash flow scenario
      expect(report.predictive.cashFlow.days, 14);
      expect(report.predictive.cashFlow.expectedTotal, greaterThan(0.0));
      expect(report.predictive.cashFlow.p10Pessimistic, lessThanOrEqualTo(report.predictive.cashFlow.expectedTotal));
      expect(report.predictive.cashFlow.p90Optimistic, greaterThanOrEqualTo(report.predictive.cashFlow.expectedTotal));

      // Verify Customer Queue Flow
      expect(report.predictive.queueFlowTomorrow.length, 24);
      final rushHour = report.predictive.queueFlowTomorrow.firstWhere((q) => q.arrivalRate > 0);
      expect(rushHour.serviceCapacity, greaterThan(0));

      // Verify Category Demand Flow
      expect(report.predictive.categoryFlows.isNotEmpty, isTrue);

      // Verify Customer RFM Segmentation
      expect(report.prescriptive.rfmSegments.length, 5);
      final champions = report.prescriptive.rfmSegments.firstWhere((s) => s.name.contains('Champion'));
      expect(champions.customerCount, greaterThan(0));
      expect(report.prescriptive.retentionRate, greaterThan(0.0));

      // Test CSV Export auto-spacing on words and numbers
      final csv = ExportCsvUtil.buildAnalyticsCsv(report, AnalyticsExportSection.full);
      expect(csv, contains('### P1. MACHINE LEARNING MODEL SCORECARD'));
      expect(csv, contains('### P2. CASH FLOW SCENARIOS'));
      expect(csv, contains('### P6. CUSTOMER QUEUE FLOW SIMULATION'));
      expect(csv, contains('### R7. CUSTOMER RFM SEGMENTATION'));

      // Verify table column alignment
      final lines = csv.split('\n');
      final p1Header = lines.firstWhere((l) => l.contains('Model Name'));
      final p1FirstRow = lines[lines.indexOf(p1Header) + 1];

      // Columns should be aligned with comma-space delimiter
      expect(p1Header.contains(', '), isTrue);
      expect(p1FirstRow.contains(', '), isTrue);
    });
  });
}
