import 'package:cafeana_app/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CafeanaApp smoke test — renders without crashing',
      (WidgetTester tester) async {
    // Wrap in ProviderScope; Firebase is not initialized in tests so the app
    // will show an error or the login placeholder.
    await tester.pumpWidget(
      const ProviderScope(
        child: CafeanaApp(),
      ),
    );
    // The widget tree should build without throwing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
