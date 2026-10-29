import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/config/theme/app_theme.dart';
import 'package:quick_commerce_seller/core/widgets/async_state_view.dart';

Widget _host(Widget child) => ProviderScope(
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('loading shows a spinner, not empty content', (tester) async {
    await tester.pumpWidget(
      _host(
        AsyncStateView<List<String>>(
          value: const AsyncValue.loading(),
          onRetry: () {},
          builder: (data) => Text('rows: ${data.length}'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // The old `.value ?? []` pattern rendered "rows: 0" here, which reads as
    // "you have nothing" rather than "still loading".
    expect(find.text('rows: 0'), findsNothing);
  });

  testWidgets('error shows a retry that re-runs the request', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(
        AsyncStateView<List<String>>(
          value: AsyncValue.error('boom', StackTrace.empty),
          onRetry: () => retries++,
          builder: (data) => Text('rows: ${data.length}'),
        ),
      ),
    );

    expect(find.text("Couldn't load this"), findsOneWidget);
    expect(find.text('rows: 0'), findsNothing);

    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });

  testWidgets('data renders through the builder', (tester) async {
    await tester.pumpWidget(
      _host(
        AsyncStateView<List<String>>(
          value: const AsyncValue.data(['a', 'b']),
          onRetry: () {},
          enableRefresh: false,
          builder: (data) => Text('rows: ${data.length}'),
        ),
      ),
    );

    expect(find.text('rows: 2'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('empty predicate shows the empty state', (tester) async {
    await tester.pumpWidget(
      _host(
        AsyncStateView<List<String>>(
          value: const AsyncValue.data([]),
          onRetry: () {},
          isEmpty: (data) => data.isEmpty,
          emptyTitle: 'No payouts yet',
          builder: (data) => Text('rows: ${data.length}'),
        ),
      ),
    );

    expect(find.text('No payouts yet'), findsOneWidget);
  });

  testWidgets('pull-to-refresh calls onRetry', (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      _host(
        AsyncStateView<List<String>>(
          value: const AsyncValue.data(['a']),
          onRetry: () => retries++,
          builder: (data) => ListView(
            children: const [SizedBox(height: 600, child: Text('row'))],
          ),
        ),
      ),
    );

    await tester.fling(find.text('row'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(retries, 1);
  });
}
