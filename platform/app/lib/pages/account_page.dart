import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../app.dart';
import '../format.dart';
import '../widgets/ui.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context);
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    return PageBody(
      maxWidth: 700,
      children: [
        const PageHeader('Account'),
        Section(
          title: 'You',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Field('Name', me.fullName),
              Field('Email', email),
              Field('Business', me.businessName),
              Field('Role', roles[me.role] ?? me.role),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.go('/set-password'),
                    icon: const Icon(Icons.password),
                    label: const Text('Change password'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const TwoStepSection(),
      ],
    );
  }
}

/// Your own two-step sign-in: off by default, each person turns it on or off.
class TwoStepSection extends StatefulWidget {
  const TwoStepSection({super.key});

  @override
  State<TwoStepSection> createState() => _TwoStepSectionState();
}

class _TwoStepSectionState extends State<TwoStepSection> {
  Key _key = UniqueKey();

  GoTrueMFAApi get _mfa => Supabase.instance.client.auth.mfa;

  Future<List<Factor>> _load() async =>
      (await _mfa.listFactors()).totp.where((f) => f.status == FactorStatus.verified).toList();

  Future<void> _turnOff(List<Factor> factors) async {
    if (!await confirm(
      context,
      'Turn off two-step sign-in?',
      "You'll sign in with just your email and password. Anyone who learns your password could then see your "
          "customers' chats and details.",
      action: 'Turn off',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await run(context, () async {
      for (final f in factors) {
        await _mfa.unenroll(f.id);
      }
      await Supabase.instance.client.auth.refreshSession();
    }, done: 'Two-step sign-in is off.');
    if (ok) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Two-step sign-in',
      child: Loader<List<Factor>>(
        key: _key,
        load: _load,
        builder: (context, factors, _) {
          final on = factors.isNotEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(on ? 'On' : 'Off', style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Text(
                on
                    ? 'Each time you sign in, you enter a code from your authenticator app after your password.'
                    : 'Add a code from an authenticator app on your phone after your password, so nobody can get in '
                          "with your password alone. Recommended, because this holds your customers' chats.",
              ),
              const SizedBox(height: 12),
              on
                  ? OutlinedButton(onPressed: () => _turnOff(factors), child: const Text('Turn off'))
                  : FilledButton(onPressed: () => context.go('/two-step-sign-in'), child: const Text('Turn on')),
            ],
          );
        },
      ),
    );
  }
}
