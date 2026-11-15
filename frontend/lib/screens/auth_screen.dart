import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../services/abaq_api.dart';
import '../theme/abaq_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.api,
    required this.onAuthenticated,
    super.key,
  });

  final AbaqApi api;
  final Future<void> Function(AuthSession) onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _isSubmitting = false;
  bool _humanVerified = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final session = _isRegistering
          ? await widget.api.register(
              name: _nameController.text.trim(),
              email: _emailController.text.trim(),
              phone: _phoneController.text.trim(),
              address: _addressController.text.trim(),
              password: _passwordController.text,
            )
          : await widget.api.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
              humanVerified: _humanVerified,
            );
      if (!mounted) return;
      await widget.onAuthenticated(session);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _fillDemoAccount() {
    setState(() {
      _isRegistering = false;
      _errorMessage = null;
      _emailController.text = 'ali@abaq.com';
      _passwordController.text = '123456';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.abaqPalette;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'A B A Q',
          style: TextStyle(fontSize: 13, letterSpacing: 3),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.border),
            ),
            child: Icon(Icons.person_outline, color: palette.accent, size: 38),
          ),
          const SizedBox(height: 24),
          Text(
            _isRegistering ? 'A place of your own.' : 'Welcome back.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            _isRegistering
                ? 'Create your Abaq account to keep your fragrance journey close.'
                : 'Sign in to revisit your orders and personal details.',
            style: TextStyle(color: palette.secondaryText, height: 1.5),
          ),
          const SizedBox(height: 22),
          Form(
            key: _formKey,
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _isRegistering
                      ? Column(
                          key: const ValueKey('registration-fields'),
                          children: [
                            _AuthField(
                              controller: _nameController,
                              label: 'Full name',
                              icon: Icons.badge_outlined,
                              textCapitalization: TextCapitalization.words,
                              validator: (value) =>
                                  value == null || value.trim().length < 2
                                  ? 'Enter your full name'
                                  : null,
                            ),
                            const SizedBox(height: 13),
                            _AuthField(
                              controller: _phoneController,
                              label: 'Phone number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                final digits = (value ?? '').replaceAll(
                                  RegExp(r'\D'),
                                  '',
                                );
                                return digits.length < 7 || digits.length > 15
                                    ? 'Enter a valid phone number'
                                    : null;
                              },
                            ),
                            const SizedBox(height: 13),
                            _AuthField(
                              controller: _addressController,
                              label: 'Delivery address',
                              icon: Icons.location_on_outlined,
                              textCapitalization: TextCapitalization.sentences,
                              validator: (value) =>
                                  value == null || value.trim().length < 5
                                  ? 'Enter your delivery address'
                                  : null,
                            ),
                            const SizedBox(height: 13),
                          ],
                        )
                      : const SizedBox.shrink(key: ValueKey('login-fields')),
                ),
                _AuthField(
                  controller: _emailController,
                  label: 'Email address',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) =>
                      value != null &&
                          RegExp(
                            r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                          ).hasMatch(value.trim())
                      ? null
                      : 'Enter a valid email address',
                ),
                const SizedBox(height: 13),
                _AuthField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: true,
                  autofillHints: [
                    _isRegistering
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                  ],
                  validator: (value) => value == null || value.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
              ],
            ),
          ),
          if (!_isRegistering) ...[
            CheckboxListTile(
              key: const ValueKey('human-verification'),
              value: _humanVerified,
              onChanged: _isSubmitting
                  ? null
                  : (verified) => setState(() {
                      _humanVerified = verified ?? false;
                    }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text("I'm not a robot"),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('fill-demo-account'),
                onPressed: _fillDemoAccount,
                style: TextButton.styleFrom(foregroundColor: palette.text),
                icon: Icon(
                  Icons.auto_awesome_outlined,
                  size: 16,
                  color: palette.accent,
                ),
                label: const Text('FILL DEMO ACCOUNT'),
              ),
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.dangerSurface,
                border: Border.all(
                  color: palette.danger.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: palette.danger, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const ValueKey('auth-submit'),
              onPressed: _isSubmitting || (!_isRegistering && !_humanVerified)
                  ? null
                  : _submit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.buttonText,
                      ),
                    )
                  : Text(
                      _isRegistering ? 'CREATE ACCOUNT' : 'SIGN IN',
                      style: const TextStyle(fontSize: 11, letterSpacing: 1.5),
                    ),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isRegistering ? 'Already have an account?' : 'New to Abaq?',
                style: TextStyle(color: palette.secondaryText),
              ),
              TextButton(
                key: const ValueKey('switch-auth-mode'),
                onPressed: _isSubmitting
                    ? null
                    : () => setState(() {
                        _isRegistering = !_isRegistering;
                        _humanVerified = false;
                        _errorMessage = null;
                      }),
                child: Text(_isRegistering ? 'Sign in' : 'Create account'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Your account is optional. You can continue browsing as a guest.',
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.secondaryText, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.validator,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?) validator;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      autofillHints: autofillHints,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 19),
        filled: true,
      ),
    );
  }
}
