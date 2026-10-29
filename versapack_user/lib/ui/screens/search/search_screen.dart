import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../navigation/route_paths.dart';
import '../../common/voice_search.dart';
import '../../common/widgets/cards/product_card.dart';
import '../../common/widgets/inputs/search_bar_widget.dart';
import '../../common/widgets/loaders/product_card_skeleton.dart';
import '../../common/widgets/misc/section_header.dart';
import '../../common/widgets/states/empty_state_widget.dart';
import '../../common/widgets/states/error_state_widget.dart';
import '../cart/widgets/cart_summary_bar.dart';
import '../category/categories/categories_provider.dart';
import '../home/home_provider.dart';
import 'search_provider.dart';
import 'search_state.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.autoStartVoice = false});

  /// When true, voice search opens automatically on entry — used when the user
  /// tapped the mic on a read-only search bar (Home / Categories) that only
  /// navigates here.
  final bool autoStartVoice;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent * 0.8) {
        ref.read(searchProvider.notifier).loadMore();
      }
    });
    if (widget.autoStartVoice) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startVoiceSearch());
    }
  }

  Future<void> _startVoiceSearch() async {
    final spoken = await VoiceSearch.run(context);
    if (spoken == null || !mounted) return;
    _runQuery(spoken);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _runQuery(String query) {
    _controller.text = query;
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
    ref.read(searchProvider.notifier)
      ..onQueryChanged(query)
      ..commitSearch(query);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchProvider);
    final homeState = ref.watch(homeProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.lg),
          child: SearchBarWidget(
            controller: _controller,
            autofocus: true,
            categories: homeState.categories.map((c) => c.name).toList(),
            onChanged: ref.read(searchProvider.notifier).onQueryChanged,
            onSubmitted: (value) =>
                ref.read(searchProvider.notifier).commitSearch(value),
            onMicTap: _startVoiceSearch,
          ),
        ),
      ),
      bottomNavigationBar: const CartSummaryBar(),
      body: SafeArea(child: _body(context, state)),
    );
  }

  Widget _body(BuildContext context, SearchState state) {
    if (state.showIdleState) return _idle(context, state);

    if (state.isLoading && state.results.isEmpty) {
      return ProductGridSkeleton(columns: context.productGridColumns);
    }
    if (state.failure != null && state.results.isEmpty) {
      return ErrorStateWidget(
        failure: state.failure!,
        onRetry: () => ref.read(searchProvider.notifier).search(state.query),
      );
    }
    if (state.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.search_off_rounded,
        title: 'No results for "${state.query}"',
        message: 'Check the spelling, or try one of the popular searches below.',
        actionLabel: 'Browse categories',
        onAction: () => context.go(RoutePaths.categories),
      );
    }

    return _results(context, state);
  }

  Widget _idle(BuildContext context, SearchState state) {
    final categories =
        ref.watch(categoriesProvider).valueOrNull?.take(8).toList() ??
            const [];

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      children: [
        if (state.recentSearches.isNotEmpty) ...[
          SectionHeader(
            title: 'Recent searches',
            trailing: TextButton(
              onPressed: ref.read(searchProvider.notifier).clearRecent,
              child: Text(
                'Clear',
                style: context.text.labelMedium!
                    .copyWith(color: context.semantic.danger),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: state.recentSearches
                  .map(
                    (term) => _QueryChip(
                      label: term,
                      icon: Icons.history_rounded,
                      onTap: () => _runQuery(term),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        // "Popular" entry points are the live top-level categories — the
        // backend has no trending-search endpoint of its own.
        if (categories.isNotEmpty) ...[
          const SectionHeader(title: 'Popular right now'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: categories
                  .map(
                    (category) => _QueryChip(
                      label: category.name,
                      icon: Icons.trending_up_rounded,
                      onTap: () => _runQuery(category.name),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _results(BuildContext context, SearchState state) {
    final sections = state.grouped.entries.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      itemCount: sections.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= sections.length) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          );
        }

        final entry = sections[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: entry.key,
              subtitle: '${entry.value.length} results',
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: entry.value.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: context.productGridColumns,
                mainAxisSpacing: AppSpacing.md,
                crossAxisSpacing: AppSpacing.md,
                childAspectRatio: 0.58,
              ),
              itemBuilder: (context, i) {
                final product = entry.value[i];
                return ProductCard(
                  product: product,
                  width: double.infinity,
                  heroTag: 'search-${entry.key}',
                  onTap: () {
                    ref.read(searchProvider.notifier).commitSearch(state.query);
                    context.push(
                      RoutePaths.productDetailsOf(product.id),
                      extra: product,
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _QueryChip extends StatelessWidget {
  const _QueryChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: context.semantic.surfaceAlt,
          borderRadius: AppRadii.rPill,
          border: Border.all(color: context.semantic.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: context.semantic.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Text(label, style: context.text.labelMedium),
          ],
        ),
      ),
    );
  }
}
