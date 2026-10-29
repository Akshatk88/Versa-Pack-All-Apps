import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/features/support/presentation/controllers/support_controller.dart';

class HelpCenterScreen extends ConsumerWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final helpAsync = ref.watch(helpCenterFaqProvider);

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.textPrimary,
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Help Center & FAQ',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: helpAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load Help Center',
                    style: AppTextStyles.h4.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.refresh(helpCenterFaqProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (data) {
            final faqItems = _parseFaqItems(data.content);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.help_center_outlined,
                          color: AppColors.primaryDark,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.title.isNotEmpty
                                  ? data.title
                                  : 'Seller Partner Help Center',
                              style: AppTextStyles.h4.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Find answers to common seller questions below',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (faqItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Text(
                      _cleanHtml(data.content),
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: context.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  )
                else
                  ...faqItems.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: context.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: context.borderColor),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        leading: const Icon(
                          Icons.question_answer_outlined,
                          color: AppColors.primaryDark,
                          size: 22,
                        ),
                        title: Text(
                          item.question,
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        expandedAlignment: Alignment.topLeft,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          Text(
                            item.answer,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: context.textPrimary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                if (data.email.isNotEmpty || data.mobile.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Still need help?',
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Contact seller support team directly:',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (data.email.isNotEmpty)
                          Row(
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                size: 18,
                                color: AppColors.primaryDark,
                              ),
                              const SizedBox(width: 8),
                              SelectableText(
                                data.email,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        if (data.mobile.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 18,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 8),
                                SelectableText(
                                  data.mobile,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: context.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static List<_FaqPair> _parseFaqItems(String htmlContent) {
    final List<_FaqPair> list = [];
    final liRegex = RegExp(r'<li>(.*?)<\/li>', dotAll: true);
    final matches = liRegex.allMatches(htmlContent);

    for (final match in matches) {
      final inner = match.group(1) ?? '';
      final strongRegex = RegExp(r'<strong>(.*?)<\/strong>', dotAll: true);
      final strongMatch = strongRegex.firstMatch(inner);

      if (strongMatch != null) {
        final q = strongMatch.group(1) ?? '';
        var a = inner.replaceAll(strongMatch.group(0)!, '');
        a = _cleanHtml(a);
        list.add(_FaqPair(question: _cleanHtml(q), answer: a));
      } else {
        final parts = inner.split('<br/>');
        if (parts.length > 1) {
          list.add(
            _FaqPair(
              question: _cleanHtml(parts.first),
              answer: _cleanHtml(parts.sublist(1).join(' ')),
            ),
          );
        } else {
          final clean = _cleanHtml(inner);
          if (clean.isNotEmpty) {
            list.add(_FaqPair(question: clean, answer: ''));
          }
        }
      }
    }

    return list;
  }

  static String _cleanHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .trim();
  }
}

class _FaqPair {
  final String question;
  final String answer;

  _FaqPair({required this.question, required this.answer});
}
