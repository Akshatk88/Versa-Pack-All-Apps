import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/features/analytics/presentation/views/analytics_screen.dart';

void main() {
  testWidgets('AnalyticsScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AnalyticsScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsScreen), findsOneWidget);
  });
}
