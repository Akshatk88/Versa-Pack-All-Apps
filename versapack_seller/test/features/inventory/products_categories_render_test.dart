import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/views/categories_screen.dart';
import 'package:quick_commerce_seller/features/inventory/presentation/views/products_screen.dart';

void main() {
  testWidgets('ProductsScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ProductsScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ProductsScreen), findsOneWidget);
  });

  testWidgets('CategoriesScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CategoriesScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CategoriesScreen), findsOneWidget);
  });
}
