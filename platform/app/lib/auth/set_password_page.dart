import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'auth_pages.dart';

/// Choosing a password: opened from the setup link IsangoTech sends a new
/// owner (the link signs them in), or from Account to change it.
class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key});

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false;

  static final _rules = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{12,}$');

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await run(context, () => repo.setPassword(_password.text), done: 'Your password is saved.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return AuthCard(
        title: 'This link has expired',
        subtitle:
            'Setup links work once and only for a limited time. Ask IsangoTech for a new one, or sign in if '
            'you already have a password.',
        children: [FilledButton(onPressed: () => context.go('/sign-in'), child: const Text('Sign in'))],
      );
    }
    return AuthCard(
      title: 'Choose your password',
      subtitle:
          'For ${session.user.email}. Use at least 12 characters, with a capital letter, a small letter and '
          'a number.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  autofocus: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'New password'),
                  validator: (v) => _rules.hasMatch(v ?? '')
                      ? null
                      : 'At least 12 characters, with a capital letter, a small letter and a number',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _again,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: const InputDecoration(labelText: 'The same password again'),
                  validator: (v) => v == _password.text ? null : "The two passwords don't match",
                  onFieldSubmitted: (_) => _save(),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save password')),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Not now', style: TextStyle(color: Brand.indigo)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
