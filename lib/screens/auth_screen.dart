import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../services/supabase_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Image.asset('assets/images/logo.png', height: 80),
                  const SizedBox(height: 12),
                  Text(
                    'FitGo',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Welcome back!' : 'Create your account',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 40),

                  // Email
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (v) {
                      if (v == null || !v.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),

                  // Forgot password (login only)
                  if (_isLogin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _handleForgotPassword,
                        child: const Text('Forgot password?'),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Error message
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              size: 18, color: cs.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style:
                                  TextStyle(fontSize: 12, color: cs.error),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _loading ? null : _handleSubmit,
                      child: _loading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : Text(_isLogin ? 'Sign In' : 'Create Account'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      Expanded(child: Divider(color: cs.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('or',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ),
                      Expanded(child: Divider(color: cs.outlineVariant)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Sign In
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _handleGoogleSignIn,
                      icon: const Text('G',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDB4437),
                          )),
                      label: const Text('Continue with Google'),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Toggle login/signup
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin
                            ? "Don't have an account?"
                            : 'Already have an account?',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                  _isLogin = !_isLogin;
                                  _error = null;
                                }),
                        child: Text(_isLogin ? 'Sign Up' : 'Sign In'),
                      ),
                    ],
                  ),

                  // Skip for now
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : _handleSkip,
                    child: Text(
                      'Skip for now (offline only)',
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        await SupabaseService.signIn(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
      } else {
        final res = await SupabaseService.signUp(
          email: _emailCtrl.text.trim(),
          password: _passCtrl.text,
        );
        if (res.user != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Check email for verification.'),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Something went wrong. Try again.');
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

    try {
      await SupabaseService.resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent!')),
        );
      }
    } catch (e) {
      setState(() => _error = 'Failed to send reset email');
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await SupabaseService.signInWithGoogle();
    } catch (e) {
      setState(() => _error = 'Google sign-in failed. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleSkip() {
    // Navigate past auth — app works offline with Hive only
    Navigator.of(context).pop();
  }
}
