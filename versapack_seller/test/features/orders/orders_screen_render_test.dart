import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/features/orders/presentation/views/orders_screen.dart';

void main() {
  testWidgets('OrdersScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: OrdersScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(OrdersScreen), findsOneWidget);
  });
}
