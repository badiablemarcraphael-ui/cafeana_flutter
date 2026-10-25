import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/order_notification_watcher.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/app_background.dart';
import '../core/widgets/cafeana_loading_screen.dart';
import 'router.dart';

/// Root widget of the Cafeana application.
///
/// Binds the [GoRouter] (from [routerProvider]) to [MaterialApp.router].
class CafeanaApp extends ConsumerWidget {
  const CafeanaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep order notification watcher active across the entire application lifecycle
    ref.watch(orderNotificationWatcherProvider);

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Cafeana',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        // Dead screen prevention: never render an empty or dead container
        return AppBackground(
          child: child ?? const CafeanaLoadingScreen(),
        );
      },
    );
  }
}

