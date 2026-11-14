import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../services/supabase_service.dart';
import '../ui/components/fitgo_card.dart';
import '../ui/components/fitgo_mark.dart';
import '../ui/components/fitgo_primary_button.dart';
import '../ui/theme/fitgo_tokens.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  bool _showEmail = false;
  bool _submitted = false;
  bool _resetSent = false;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passFocus = FocusNode();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final isApple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    return Scaffold(
      backgroundColor: tokens.surfaceMuted,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tokens.surfaceMuted, tokens.surface],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -70,
              child: _Glow(color: tokens.ember, size: 260),
            ),
            Positioned(
              bottom: -120,
              left: -90,
              child: _Glow(color: tokens.amber, size: 300),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: FitGoSpacing.xl,
                    vertical: FitGoSpacing.xxl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: FitGoMark(size: 64)),
                        const SizedBox(height: FitGoSpacing.sm),
                        Center(
                          child: Text(
                            'FitGo',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: tokens.ember,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: FitGoSpacing.xxl),
                        Text(
                          'Your day, in balance.',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: tokens.textPrimary,
                          ),
                        ),
                        const SizedBox(height: FitGoSpacing.xs),
                        Text(
                          'Calories, fasting, water, sleep, and progress — in '
                          'one calm place.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                        const SizedBox(height: FitGoSpacing.xxl),

                        // App Store guideline 4.8: Apple first when Google is
                        // also offered.
                        if (isApple) ...[
                          SizedBox(
                            height: 50,
                            child: SignInWithAppleButton(
                              onPressed: _loading ? null : _handleAppleSignIn,
                              height: 50,
                              borderRadius: BorderRadius.circular(
                                FitGoRadii.input,
                              ),
                              style: theme.brightness == Brightness.dark
                                  ? SignInWithAppleButtonStyle.white
                                  : SignInWithAppleButtonStyle.black,
                            ),
                          ),
                          const SizedBox(height: FitGoSpacing.sm),
                        ],
                        SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _handleGoogleSignIn,
                            icon: Text(
                              'G',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: tokens.danger,
                              ),
                            ),
                            label: const Text('Continue with Google'),
                          ),
                        ),
                        const SizedBox(height: FitGoSpacing.sm),
                        SizedBox(
                          height: 48,
                          child: TextButton.icon(
                            onPressed: _loading
                                ? null
                                : () {
                                    setState(() {
                                      _showEmail = !_showEmail;
                                      _error = null;
                                      _resetSent = false;
                                    });
                                  },
                            icon: Icon(
                              _showEmail
                                  ? Icons.keyboard_arrow_up
                                  : Icons.mail_outline,
                              size: 20,
                            ),
                            label: Text(
                              _showEmail
                                  ? 'Hide email sign in'
                                  : 'Continue with email',
                            ),
                          ),
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: _showEmail
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    top: FitGoSpacing.md,
                                  ),
                                  child: _buildEmailForm(context),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: FitGoSpacing.xl),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => context.push('/onboarding'),
                          child: const Text('Continue without an account'),
                        ),
                        const SizedBox(height: FitGoSpacing.xs),
                        Text.rich(
                          TextSpan(
                            text: 'By continuing you agree to our ',
                            children: const [
                              TextSpan(
                                text: 'Terms',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              TextSpan(text: '.'),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ],
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

  Widget _buildEmailForm(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;

    return FitGoCard(
      padding: const EdgeInsets.all(FitGoSpacing.lg),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isLogin ? 'Welcome back' : 'Create your account',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: FitGoSpacing.md),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (!email.contains('@') || !email.contains('.')) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _passFocus.requestFocus(),
              ),
              const SizedBox(height: FitGoSpacing.sm),
              TextFormField(
                controller: _passCtrl,
                focusNode: _passFocus,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: [
                  _isLogin ? AutofillHints.password : AutofillHints.newPassword,
                ],
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (!_loading) _handleSubmit();
                },
              ),
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _handleForgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                ),
              if (_error != null) ...[
                _InlineMessage(
                  message: _error!,
                  icon: Icons.error_outline,
                  color: tokens.danger,
                ),
                const SizedBox(height: FitGoSpacing.sm),
              ],
              if (_resetSent) ...[
                _InlineMessage(
                  message: 'Password reset email sent. Check your inbox.',
                  icon: Icons.mark_email_read_outlined,
                  color: tokens.mint,
                ),
                const SizedBox(height: FitGoSpacing.sm),
              ],
              const SizedBox(height: FitGoSpacing.xs),
              FitGoPrimaryButton(
                label: _isLogin ? 'Sign In' : 'Create Account',
                onPressed: _handleSubmit,
                loading: _loading,
              ),
              const SizedBox(height: FitGoSpacing.sm),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    _isLogin
                        ? "Don't have an account?"
                        : 'Already have an account?',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () {
                            setState(() {
                              _isLogin = !_isLogin;
                              _error = null;
                              _resetSent = false;
                            });
                          },
                    child: Text(_isLogin ? 'Sign Up' : 'Sign In'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _submitted = true;
      _error = null;
      _resetSent = false;
    });
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await SupabaseService.signIn(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        if (mounted) {
          // The router sends signed-in users to onboarding or the app.
          context.go('/');
        }
      } else {
        final response = await SupabaseService.signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        if (response.user != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Check email for verification.'),
            ),
          );
        }
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email first');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resetSent = false;
    });

    try {
      await SupabaseService.resetPassword(email);
      if (mounted) setState(() => _resetSent = true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Failed to send reset email. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
      _resetSent = false;
    });

    try {
      await SupabaseService.signInWithGoogle();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Google sign-in failed. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
      _resetSent = false;
    });

    try {
      await SupabaseService.signInWithApple();
      if (mounted) {
        context.go('/');
      }
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.code == AuthorizationErrorCode.canceled
              ? 'Apple sign-in was cancelled.'
              : 'Apple sign-in failed. Try again.';
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Apple sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.icon,
    required this.color,
  });

  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textColor = Theme.of(context).brightness == Brightness.dark
        ? color
        : Color.lerp(color, tokens.textPrimary, 0.25)!;

    return Container(
      padding: const EdgeInsets.all(FitGoSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(FitGoRadii.input),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: FitGoSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
