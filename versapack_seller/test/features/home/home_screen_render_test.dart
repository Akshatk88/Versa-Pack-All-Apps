import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/config/theme/app_theme.dart';
import 'package:quick_commerce_seller/features/home/presentation/views/home_screen.dart';

void main() {
  // Must use AppTheme, not the default MaterialApp theme: the bug that blanked
  // this screen lived in AppTheme's button minimumSize, so a default-theme
  // pump renders fine and proves nothing.
  testWidgets('HomeScreen renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
