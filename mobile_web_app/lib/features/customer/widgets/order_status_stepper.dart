import 'package:flutter/material.dart';

import '../../../core/models/order.dart';

/// Displays order progress as a horizontal timeline stepper.
///
/// The [currentStatus] determines which step is active and which are complete.
class OrderStatusStepper extends StatelessWidget {
  const OrderStatusStepper({required this.currentStatus, super.key});

  final OrderStatus currentStatus;

  static const _steps = [
    OrderStatus.queued,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.received,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currentIndex = _steps.indexOf(currentStatus);

    return Column(
      children: [
        // ── Step indicators ─────────────────────────────────────────────────
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              _StepDot(
                status: _steps[i],
                isCompleted: i < currentIndex,
                isActive: i == currentIndex,
              ),
              if (i < _steps.length - 1)
                Expanded(
                  child: Container(
                    height: 3,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i < currentIndex
                          ? cs.primary
                          : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ],
        ),

        const SizedBox(height: 8),

        // ── Labels ──────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _steps
              .map((s) => _StepLabel(
                    label: s.label,
                    isActive: s == currentStatus,
                    isCompleted: _steps.indexOf(s) < currentIndex,
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ── Step dot ──────────────────────────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.status,
    required this.isCompleted,
    required this.isActive,
  });

  final OrderStatus status;
  final bool isCompleted;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final color = isCompleted || isActive ? cs.primary : cs.outlineVariant;
    final size = isActive ? 32.0 : 24.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? cs.primary
            : isActive
                ? cs.primaryContainer
                : cs.surfaceContainerHighest,
        border: Border.all(color: color, width: isActive ? 2.5 : 1.5),
      ),
      child: Center(
        child: isCompleted
            ? Icon(Icons.check, size: 14, color: cs.onPrimary)
            : isActive
                ? Icon(_iconFor(status), size: 14, color: cs.primary)
                : null,
      ),
    );
  }

  IconData _iconFor(OrderStatus status) => switch (status) {
        OrderStatus.queued => Icons.access_time,
        OrderStatus.preparing => Icons.soup_kitchen_outlined,
        OrderStatus.ready => Icons.done_all,
        OrderStatus.received => Icons.shopping_bag_outlined,
        OrderStatus.completed => Icons.star_outline,
        OrderStatus.cancelled => Icons.cancel_outlined,
      };
}

// ── Step label ────────────────────────────────────────────────────────────────

class _StepLabel extends StatelessWidget {
  const _StepLabel({
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 60,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
          color: isActive || isCompleted ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
