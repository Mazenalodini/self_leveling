import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/input_field.dart';
import '../../../core/utils/feedback_utils.dart';
import '../../../widgets/system_decorative_line.dart';
import '../../../navigation/app_router.dart';
import '../../../providers/app_init_provider.dart';
import '../../../data/repositories/auth_repository.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    setState(() {
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
    });

    bool hasError = false;

    if (email.isEmpty) {
      _emailError = 'Email cannot be empty';
      hasError = true;
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _emailError = 'Please enter a valid email form';
      hasError = true;
    }

    if (password.isEmpty) {
      _passwordError = 'Password cannot be empty';
      hasError = true;
    } else if (password.length < 6) {
      _passwordError = 'Password must be at least 6 characters';
      hasError = true;
    }

    if (confirm != password) {
      _confirmError = 'Passwords do not match';
      hasError = true;
    }

    if (hasError) {
      setState(() {});
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signUpWithEmail(email, password);
      
      // Notify AppInitNotifier to refresh and route
      await ref.read(appInitProvider.notifier).completeLogin();
      if (mounted) context.go(RoutePaths.boot);
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, 'Sign up failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogle();
      
      // Notify AppInitNotifier to refresh and route
      await ref.read(appInitProvider.notifier).completeLogin();
      if (mounted) context.go(RoutePaths.boot);
    } catch (e) {
      if (e.toString().contains('canceled')) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (!mounted) return;
      AppFeedback.showError(context, 'Google Sign-In failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SystemBackground(
        particleCount: 10,
        child: Stack(
          children: [
            // Grid overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(painter: _GridPainter()),
              ),
            ),

            // Corner decorations
            Positioned(
              top: 0,
              right: 0,
              child: _corner(true),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: _corner(false),
            ),

            // Back button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 24,
              child: GestureDetector(
                onTap: () => context.pop(),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 8),
                    Text(AppStrings.back, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ).animate().fadeIn(duration: 500.ms),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      GlowCard(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Text(AppStrings.createYourAccount, style: AppTextStyles.h2)
                                .animate().fadeIn(delay: 200.ms),
                            const SizedBox(height: 8),
                            Text(AppStrings.startTransformation, style: AppTextStyles.secondaryText)
                                .animate().fadeIn(delay: 300.ms),
                            const SizedBox(height: 40),

                            InputField(
                              label: AppStrings.email,
                              placeholder: AppStrings.emailPlaceholder,
                              prefixIcon: Icons.mail_outline,
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              errorText: _emailError,
                              textDirection: TextDirection.ltr,
                              onChanged: (_) {
                                if (_emailError != null) setState(() => _emailError = null);
                              },
                            ),
                            const SizedBox(height: 20),

                            InputField(
                              label: AppStrings.password,
                              placeholder: AppStrings.passwordPlaceholder,
                              prefixIcon: Icons.lock_outline,
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              errorText: _passwordError,
                              textDirection: TextDirection.ltr,
                              obscureText: !_showPassword,
                              onChanged: (_) {
                                if (_passwordError != null) setState(() => _passwordError = null);
                              },
                              suffixWidget: GestureDetector(
                                onTap: () => setState(() => _showPassword = !_showPassword),
                                child: Icon(
                                  _showPassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textSecondary, size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            InputField(
                              label: AppStrings.confirmPassword,
                              placeholder: AppStrings.passwordPlaceholder,
                              prefixIcon: Icons.lock_outline,
                              controller: _confirmPasswordController,
                              focusNode: _confirmFocusNode,
                              errorText: _confirmError,
                              textDirection: TextDirection.ltr,
                              obscureText: !_showConfirmPassword,
                              onChanged: (_) {
                                if (_confirmError != null) setState(() => _confirmError = null);
                              },
                              suffixWidget: GestureDetector(
                                onTap: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                                child: Icon(
                                  _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.textSecondary, size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : GlowButton(
                                    text: AppStrings.createAccount,
                                    onPressed: _handleSignUp,
                                  ).animate().fadeIn(delay: 700.ms),
                            const SizedBox(height: 32),

                            // Divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          AppColors.primaryBlue.withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(AppStrings.or, style: AppTextStyles.secondaryText),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.transparent,
                                          AppColors.primaryBlue.withOpacity(0.3),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 750.ms),

                            const SizedBox(height: 32),

                            // Google sign up button
                            GestureDetector(
                              onTap: _isLoading ? null : _handleGoogleSignIn,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: AppColors.cardBackground,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const FaIcon(FontAwesomeIcons.google, color: Colors.white, size: 20),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Continue with Google',
                                      style: AppTextStyles.button.copyWith(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2),

                            const SizedBox(height: 32),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(AppStrings.alreadyHaveAccount, style: AppTextStyles.secondaryText),
                                GestureDetector(
                                  onTap: () => context.pop(),
                                  child: Text(
                                    AppStrings.login,
                                    style: AppTextStyles.label.copyWith(color: AppColors.primaryBlue),
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 800.ms),

                            const SizedBox(height: 32),
                            Opacity(
                              opacity: 0.4,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _dotWidget(4), const SizedBox(width: 8),
                                  _dotWidget(8), const SizedBox(width: 8),
                                  _dotWidget(4),
                                ],
                              ),
                            ).animate().fadeIn(delay: 900.ms),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      SystemDecorativeLine(label: AppStrings.systemRegistration)
                          .animate().fadeIn(delay: 1000.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corner(bool isTopRight) => Container(
        width: 96, height: 96,
        decoration: BoxDecoration(
          border: Border(
            top: isTopRight ? BorderSide(color: AppColors.primaryBlue.withOpacity(0.2), width: 2) : BorderSide.none,
            right: isTopRight ? BorderSide(color: AppColors.primaryBlue.withOpacity(0.2), width: 2) : BorderSide.none,
            bottom: !isTopRight ? BorderSide(color: AppColors.primaryBlue.withOpacity(0.2), width: 2) : BorderSide.none,
            left: !isTopRight ? BorderSide(color: AppColors.primaryBlue.withOpacity(0.2), width: 2) : BorderSide.none,
          ),
          borderRadius: isTopRight
              ? const BorderRadius.only(topRight: Radius.circular(24))
              : const BorderRadius.only(bottomLeft: Radius.circular(24)),
        ),
      );

  Widget _dotWidget(double size) => Container(
        width: size, height: size,
        decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
      );
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryBlue.withOpacity(0.3)
      ..strokeWidth = 1;
    const step = 50.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
