import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/application_status.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_controller.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_state.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class AccountStatusScreen extends ConsumerWidget {
  const AccountStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final summary = ref.watch(applicationSummaryProvider).value;

    // The decision comes from the auth state, which carries whatever the
    // backend said at the last sign-in attempt. There is no status endpoint a
    // seller without a token can call.
    final isRejected = auth is AuthRejected;
    final serverMessage = switch (auth) {
      AuthRejected(:final message) => message,
      AuthPendingApproval(:final message) => message,
      _ => '',
    };

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            color: context.textPrimary,
            size: 28,
          ),
          onPressed: () {
            ref.read(authControllerProvider.notifier).returnToLogin();
            context.go('/login');
          },
        ),
        title: Text(
          'Application Status',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Check status again',
            icon: Icon(
              Icons.refresh_rounded,
              color: context.textPrimary,
              size: 22,
            ),
            // Signing in again is the only way to re-read the decision, so this
            // hands the seller back to the OTP screen rather than pretending a
            // refresh endpoint exists.
            onPressed: () {
              ref.read(authControllerProvider.notifier).returnToLogin();
              context.go('/login');
            },
          ),
          IconButton(
            tooltip: 'Contact support',
            icon: Icon(
              Icons.headset_mic_outlined,
              color: context.textPrimary,
              size: 22,
            ),
            onPressed: () => context.push('/support'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Status Banner (Yellow Cream Container with Clipboard Graphic)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isRejected
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isRejected
                        ? const Color(0xFFFECACA)
                        : const Color(0xFFFEF08A),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your application is',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: context.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            isRejected ? 'Rejected' : 'Pending',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: isRejected
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isRejected
                                ? 'Your application was not approved. Contact support to find out what to fix.'
                                : 'We are reviewing your details.\nThis may take 1-2 business days.',
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Custom 3D Clipboard with Magnifying Glass & Clock
                    _buildClipboardGraphic(context),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Application Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Application Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildDetailRow(
                      icon: Icons.storefront_rounded,
                      label: 'Store Name',
                      value: summary?.hasStoreName == true
                          ? summary!.storeName
                          : 'Not available',
                    ),
                    const Divider(height: 24, color: Color(0xFFF3F4F6)),

                    _buildDetailRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Submitted On',
                      value: (summary?.submittedOnLabel ?? '').isNotEmpty
                          ? summary!.submittedOnLabel
                          : 'Not available',
                    ),
                    const Divider(height: 24, color: Color(0xFFF3F4F6)),

                    _buildDetailRow(
                      icon: Icons.assignment_outlined,
                      label: 'Application ID',
                      value: summary?.hasApplicationId == true
                          ? summary!.referenceCode
                          : 'Not available',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Review Progress Card with Hourglass Graphic
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Stack(
                  children: [
                    // Right Background Hourglass Graphic
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Opacity(
                        opacity: 0.85,
                        child: _buildHourglassGraphic(),
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Review Progress',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        _buildTimelineStep(
                          context,
                          isCompleted: true,
                          isActive: false,
                          isLast: false,
                          title: 'Application Submitted',
                          subtitle: (summary?.submittedOnLabel ?? '').isNotEmpty
                              ? summary!.submittedOnLabel
                              : 'Submitted',
                        ),
                        _buildTimelineStep(
                          context,
                          isCompleted: isRejected,
                          isActive: !isRejected,
                          isLast: false,
                          title: 'Under Review',
                          subtitle: isRejected
                              ? 'Review complete'
                              : 'Our team is verifying your details',
                        ),
                        _buildTimelineStep(
                          context,
                          isCompleted: false,
                          isActive: false,
                          isLast: false,
                          title: isRejected ? 'Not approved' : 'Approved',
                          subtitle: isRejected
                              ? 'Contact support for the reason'
                              : 'You will be notified once approved',
                        ),
                        _buildTimelineStep(
                          context,
                          isCompleted: false,
                          isActive: false,
                          isLast: true,
                          title: 'Live on App',
                          subtitle: 'Start receiving orders',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Note from Admin Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Note from Admin',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            serverMessage.isNotEmpty
                                ? serverMessage
                                : 'Please ensure all documents are clear and valid. We will notify you via email and app.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E40AF),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Need Help Card
              InkWell(
                onTap: () => context.push('/support'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.headset_mic_outlined,
                          color: Color(0xFFD97706),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Need help?',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: const Color(0xFF181C2E),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Contact our support team',
                              style: AppTextStyles.caption.copyWith(
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.textSecondary,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClipboardGraphic(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // White Board
          Container(
            width: 70,
            height: 85,
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF475569), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 14),
                // Store Roof Icon
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(height: 8),
                Container(width: 40, height: 3, color: const Color(0xFFE2E8F0)),
                const SizedBox(height: 4),
                Container(width: 30, height: 3, color: const Color(0xFFE2E8F0)),
              ],
            ),
          ),
          // Top Golden Clamp
          Positioned(
            top: 2,
            child: Container(
              width: 28,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFFD9027),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFD97706), width: 1),
              ),
            ),
          ),
          // Magnifying Glass
          Positioned(
            right: 2,
            bottom: 12,
            child: Transform.rotate(
              angle: 0.4,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E293B), width: 3),
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
          // Clock Badge
          Positioned(
            left: 2,
            bottom: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: Color(0xFFFD9027),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.access_time_filled_rounded,
                size: 16,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourglassGraphic() {
    return SizedBox(
      width: 75,
      height: 95,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.15,
            child: Container(
              width: 45,
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 2.5),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 4,
                    color: const Color(0xFF94A3B8),
                  ),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFFDE68A),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFFEF3C7),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFFD97706), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF181C2E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineStep(
    BuildContext context, {
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isCompleted
                    ? const Color(0xFFFD9027)
                    : isActive
                    ? Colors.white
                    : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted || isActive
                      ? const Color(0xFFFD9027)
                      : const Color(0xFFD1D5DB),
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? const Icon(
                      Icons.check_rounded,
                      color: Color(0xFF181C2E),
                      size: 14,
                    )
                  : isActive
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFD9027),
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                color: isCompleted
                    ? const Color(0xFFFD9027)
                    : context.borderColor,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isCompleted || isActive
                        ? FontWeight.bold
                        : FontWeight.w500,
                    color: isCompleted || isActive
                        ? const Color(0xFF181C2E)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isCompleted || isActive
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
