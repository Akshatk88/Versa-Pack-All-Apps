import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/views/add_product_screen.dart';

void main() {
  testWidgets('AddProductScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AddProductScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AddProductScreen), findsOneWidget);
  });
}
