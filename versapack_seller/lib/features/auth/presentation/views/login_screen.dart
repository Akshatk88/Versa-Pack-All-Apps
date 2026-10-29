import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/network/api_exception.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_controller.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_state.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _otp = TextEditingController();
  final GlobalKey<FormState> _phoneForm = GlobalKey<FormState>();
  final GlobalKey<FormState> _otpForm = GlobalKey<FormState>();

  bool _submitting = false;
  bool _reasonShown = false;
  final String _selectedCountryCode = '+91';

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _showError(Object error) {
    final message = error is DioException && error.error is ApiException
        ? (error.error as ApiException).message
        : error is ApiException
        ? error.message
        : 'Something went wrong. Please try again.';
    AppToast.showError(context, message);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestOtp() async {
    if (!(_phoneForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _run(
      () => ref
          .read(authControllerProvider.notifier)
          .requestOtp(_phone.text.trim()),
    );
  }

  Future<void> _verifyOtp(String phone) async {
    if (!(_otpForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    await _run(
      () => ref
          .read(authControllerProvider.notifier)
          .verifyOtp(phone: phone, otp: _otp.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);

    if (state is AuthLoggedOut && state.reason != null && !_reasonShown) {
      _reasonShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppToast.showError(context, state.reason!);
      });
    }

    // The skyline is pinned to the bottom of the Stack, so with the keyboard
    // open it sat on top of the Send OTP button and the Register link.
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: context.surface,
      body: Stack(
        children: [
          // Bottom City Skyline Background Illustration
          if (!keyboardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 120,
              child: CustomPaint(painter: _CitySkylinePainter()),
            ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    // Bottom padding clears the skyline so the last control is
                    // never underneath it.
                    padding: EdgeInsets.fromLTRB(
                      24,
                      16,
                      24,
                      keyboardOpen ? 16 : 132,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),

                        // Logo Block
                        _buildLogoHeader(),
                        const SizedBox(height: 16),

                        // Welcome Texts
                        Text(
                          'Welcome Back!',
                          style: AppTextStyles.h2.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Login to your account',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 3D Store & Scooter Illustration.
                        //
                        // Hidden while typing: with the keyboard up it and the
                        // logo filled the whole viewport, leaving the Send OTP
                        // button scrolled off the bottom as a thin sliver.
                        if (!keyboardOpen) ...[
                          _buildStoreAndScooterIllustration(),
                          const SizedBox(height: 24),
                        ],

                        // Interactive Form Step
                        if (state is AuthOtpSent)
                          _buildOtpStep(state)
                        else if (state is AuthNeedsRegistration)
                          _buildNeedsRegistration(state)
                        else
                          _buildPhoneStep(),
                      ],
                    ),
                  ),
                ),

                // Register Link Footer
                Padding(
                  padding: const EdgeInsets.only(bottom: 20, top: 10),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Don’t have an account? ",
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/registration'),
                        child: Text(
                          'Register',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: const Color(0xFFF59E0B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              fontFamily: 'Inter',
            ),
            children: [
              TextSpan(
                text: 'Versa',
                style: TextStyle(color: context.textPrimary),
              ),
              TextSpan(
                text: 'pack',
                style: TextStyle(color: Color(0xFF0F9D58)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Quick Seller',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildStoreAndScooterIllustration() {
    return SizedBox(
      height: 180,
      child: Center(
        child: Image.asset(
          'assets/images/seller_login_illustration.png',
          height: 175,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Form(
      key: _phoneForm,
      child: Column(
        children: [
          // Phone Input Box with Golden Border
          Container(
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFD9027), width: 1.5),
            ),
            child: Row(
              children: [
                // Country code dropdown button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _selectedCountryCode,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: const Color(0xFF181C2E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: context.textPrimary,
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: context.borderColor),
                const SizedBox(width: 12),

                // Mobile number field
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    enabled: !_submitting,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: const Color(0xFF181C2E),
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter mobile number',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: const Color(0xFF9CA3AF),
                      ),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      isDense: true,
                    ),
                    validator: (value) {
                      final v = (value ?? '').trim();
                      if (v.isEmpty) return 'Enter mobile number';
                      if (v.length < 10) return 'Enter valid 10-digit number';
                      return null;
                    },
                    onFieldSubmitted: (_) => _requestOtp(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Send OTP Button (Solid Golden Yellow)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : _requestOtp,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFD9027),
                foregroundColor: const Color(0xFF181C2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF181C2E),
                      ),
                    )
                  : Text(
                      'Send OTP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // OR Divider
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OR',
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF9CA3AF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE5E7EB))),
            ],
          ),
          const SizedBox(height: 20),

          // Login with Password Button (Outlined Golden Card)
          InkWell(
            onTap: () => _showPasswordLoginDialog(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFD9027), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF181C2E),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Login with password',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Security Badge Note
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Color(0xFFFD9027),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Your data is 100% secure',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtpStep(AuthOtpSent state) {
    return Form(
      key: _otpForm,
      child: Column(
        children: [
          Text(
            'Enter Verification Code',
            style: AppTextStyles.h2.copyWith(
              color: const Color(0xFF181C2E),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sent to +91 ${state.phone}',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          if (state.debugOtp != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.pendingBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Test OTP Code: ${state.debugOtp}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.pendingText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextFormField(
            controller: _otp,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
            autofocus: true,
            textAlign: TextAlign.center,
            style: AppTextStyles.h2.copyWith(
              letterSpacing: 8,
              color: const Color(0xFF181C2E),
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            decoration: InputDecoration(
              hintText: '• • • • • •',
              hintStyle: AppTextStyles.h2.copyWith(
                letterSpacing: 6,
                color: const Color(0xFF9CA3AF),
              ),
              fillColor: Colors.white,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFFD9027),
                  width: 1.5,
                ),
              ),
            ),
            validator: (value) {
              final v = (value ?? '').trim();
              if (v.isEmpty) return 'Enter code';
              if (v.length < 4) return 'Enter valid code';
              return null;
            },
            onFieldSubmitted: (_) => _verifyOtp(state.phone),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submitting ? null : () => _verifyOtp(state.phone),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFD9027),
                foregroundColor: const Color(0xFF181C2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF181C2E),
                      ),
                    )
                  : const Text(
                      'Verify OTP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF181C2E),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _submitting
                ? null
                : () {
                    _otp.clear();
                    ref.read(authControllerProvider.notifier).cancelOtp();
                  },
            child: Text(
              'Change phone number',
              style: AppTextStyles.bodyMedium.copyWith(
                color: const Color(0xFF181C2E),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNeedsRegistration(AuthNeedsRegistration state) {
    return Column(
      children: [
        Text(
          'Complete Registration',
          style: AppTextStyles.h2.copyWith(color: const Color(0xFF181C2E)),
        ),
        const SizedBox(height: 8),
        Text(
          'Phone +91 ${state.phone} verified.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => context.push('/registration'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFD9027),
              foregroundColor: const Color(0xFF181C2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Register Store Now',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF181C2E),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPasswordLoginDialog(BuildContext context) {
    final pwdCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Login with Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _requestOtp();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFD9027),
            ),
            child: const Text(
              'Login',
              style: TextStyle(color: Color(0xFF181C2E)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for soft golden city skyline vector graphic at bottom
class _CitySkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFEF08A).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final path = Path()..moveTo(0, size.height);

    // Subtle rectangular building silhouettes
    final buildings = [
      Rect.fromLTWH(0, size.height - 25, size.width * 0.12, 25),
      Rect.fromLTWH(size.width * 0.12, size.height - 40, size.width * 0.10, 40),
      Rect.fromLTWH(size.width * 0.22, size.height - 30, size.width * 0.11, 30),
      Rect.fromLTWH(size.width * 0.33, size.height - 48, size.width * 0.10, 48),
      Rect.fromLTWH(size.width * 0.43, size.height - 22, size.width * 0.12, 22),
      Rect.fromLTWH(size.width * 0.55, size.height - 42, size.width * 0.10, 42),
      Rect.fromLTWH(size.width * 0.65, size.height - 32, size.width * 0.11, 32),
      Rect.fromLTWH(size.width * 0.76, size.height - 52, size.width * 0.10, 52),
      Rect.fromLTWH(size.width * 0.86, size.height - 28, size.width * 0.14, 28),
    ];

    for (final rect in buildings) {
      path.addRect(rect);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
