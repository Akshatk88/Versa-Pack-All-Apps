import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../navigation/route_paths.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/inputs/app_text_field.dart';
import 'login_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sent = await ref.read(loginProvider.notifier).requestOtp();
    if (!sent || !mounted) return;

    final state = ref.read(loginProvider);
    context.push(
      RoutePaths.otp,
      extra: (phone: state.phone, debugOtp: state.debugOtp),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);
    // Read before removeViewInsets: the background stays put while the form
    // is lifted above the keyboard.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: MediaQuery.removeViewInsets(
        context: context,
        removeBottom: true,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Decorative backdrop only — the logo and welcome copy are drawn
            // as widgets so they move with the form when the keyboard opens.
            Image.asset('assets/images/login_bg.jpg', fit: BoxFit.cover),
            // Dark gradient overlay (optional) to ensure text remains legible at the bottom
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            SafeArea(
              bottom: keyboardInset == 0,
              child: Padding(
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    // Reversed so the input and button stay pinned above the
                    // keyboard; the header scrolls away when space runs out.
                    reverse: true,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - AppSpacing.xl * 2,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const _BrandHeader(),
                          Column(
                            children: [
                              const SizedBox(height: AppSpacing.xxl),
                              Text(
                                AppStrings.loginTitle,
                                style: context.text.displaySmall!.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                AppStrings.loginSubtitle,
                                style: context.text.bodyLarge!.copyWith(
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.xxl),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                child: AppTextField(
                                  controller: _controller,
                                  hint: '00000 00000',
                                  autofocus: true,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(10),
                                  ],
                                  errorText:
                                      state.validationError ??
                                      state.failure?.message,
                                  onChanged: ref
                                      .read(loginProvider.notifier)
                                      .setPhone,
                                  onSubmitted: (_) =>
                                      state.canSubmit ? _submit() : null,
                                  prefix: const _CountryCode(),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              PrimaryButton(
                                label: AppStrings.continueLabel,
                                isLoading: state.isSubmitting,
                                onPressed: state.canSubmit ? _submit : null,
                              ),
                              const SizedBox(height: AppSpacing.xl),
                              Text(
                                'By continuing you agree to our Terms of Service and Privacy '
                                'Policy.',
                                style: context.text.bodySmall!.copyWith(
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// App logo with the "Welcome to Versa Pack" title directly beneath it.
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  static const _brandGradient = LinearGradient(
    colors: [Color(0xFFFF1F6B), Color(0xFFFF7A2F), Color(0xFFFFC300)],
  );

  @override
  Widget build(BuildContext context) {
    final titleStyle = context.text.displaySmall!.copyWith(
      color: Colors.white,
      fontSize: 40,
      fontWeight: FontWeight.w800,
      height: 1.15,
    );

    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl),
        Image.asset('assets/images/logo_mark.png', width: 170),
        const SizedBox(height: AppSpacing.xl),
        Text('Welcome to', style: titleStyle, textAlign: TextAlign.center),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: _brandGradient.createShader,
          child: Text(
            'Versa Pack',
            style: titleStyle,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Fixed +91: the backend's OTP flow is India-only today.
class _CountryCode extends StatelessWidget {
  const _CountryCode();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.md),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🇮🇳', style: context.text.bodyLarge),
          const SizedBox(width: AppSpacing.sm),
          Text('+91', style: context.text.titleMedium),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 1,
            height: 22,
            decoration: BoxDecoration(
              color: context.semantic.border,
              borderRadius: AppRadii.rSm,
            ),
          ),
        ],
      ),
    );
  }
}
