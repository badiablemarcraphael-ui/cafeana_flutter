import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'core/services/notification_service.dart';
import 'core/widgets/cafeana_error_recovery_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Dead screen prevention: catch unhandled widget build errors
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return CafeanaErrorRecoveryScreen(
      errorMessage: details.exceptionAsString(),
    );
  };

  // Use path-based URLs on web (removes the '#' fragment).
  usePathUrlStrategy();

  // Initialise Firebase with the real project credentials.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialise cross-platform Push & Taskbar Notifications (Web & Mobile)
  await NotificationService.instance.initialize();

  runApp(
    // ProviderScope is the Riverpod dependency-injection container.
    const ProviderScope(child: CafeanaApp()),
  );
}
