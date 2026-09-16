import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/providers.dart';
import '../../widgets/lango_page.dart';
import 'auth_scaffold.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  String? _info;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      final res = await ref.read(authServiceProvider).signUp(
          email: _email.text.trim(), password: _password.text);
      if (res.session != null) {
        // Authenticated immediately → onboarding (US-001).
        ref.invalidate(profileProvider);
        if (mounted) context.go('/onboarding');
      } else {
        // Email confirmation is enabled on the Supabase project.
        setState(() =>
            _info = 'Check your email to confirm your account, then sign in.');
      }
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Start learning Korean and Japanese.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(hintText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: AuthValidators.email,
            ),
            const Gap.md(),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(
                hintText: 'Password',
                helperText: 'At least 8 characters',
              ),
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: AuthValidators.password,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const Gap.md(),
              Text(_error!,
                  style: LangoType.body.copyWith(color: LangoColors.error)),
            ],
            if (_info != null) ...[
              const Gap.md(),
              Text(_info!,
                  style: LangoType.body.copyWith(color: LangoColors.primary)),
            ],
            const Gap.xl(),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: LangoColors.primaryForeground))
                  : const Text('Create account'),
            ),
            const Gap.xs(),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
