import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoader extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const ShimmerLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16.0,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: padding,
      child: Shimmer.fromColors(
        baseColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        highlightColor: theme.colorScheme.surface,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}
