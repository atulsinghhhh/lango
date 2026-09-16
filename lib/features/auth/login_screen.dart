import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../services/providers.dart';
import '../../widgets/lango_page.dart';
import 'auth_scaffold.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;
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
    });
    try {
      await ref.read(authServiceProvider).signIn(
          email: _email.text.trim(), password: _password.text);
      ref.invalidate(profileProvider);
      if (mounted) context.go('/');
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
      title: 'Welcome back',
      subtitle: 'Pick up where you left off.',
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
              decoration: const InputDecoration(hintText: 'Password'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              validator: AuthValidators.password,
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const Gap.md(),
              Text(_error!,
                  style: LangoType.body.copyWith(color: LangoColors.error)),
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
                  : const Text('Sign in'),
            ),
            const Gap.xs(),
            TextButton(
              onPressed: () => context.go('/signup'),
              child: const Text("New here? Create an account"),
            ),
          ],
        ),
      ),
    );
  }
}
