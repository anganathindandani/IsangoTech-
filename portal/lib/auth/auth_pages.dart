import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';
import '../widgets/ui.dart';

/// Centered card used by the sign-in screens.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.title, required this.children, this.subtitle});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Brand.sand,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              semanticContainer: false,

              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(
                      'assets/brand/logo.png',
                      height: 34,
                      alignment: Alignment.centerLeft,
                      semanticLabel: 'IsangoTech',
                    ),
                    const SizedBox(height: 24),
                    Text(title, style: Theme.of(context).textTheme.headlineSmall),
                    if (subtitle != null) ...[const SizedBox(height: 8), Text(subtitle!)],
                    const SizedBox(height: 20),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      title: 'Team portal',
      subtitle: 'Sign in with your IsangoTech account.',
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  key: const Key('email'),
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('password'),
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  validator: requiredText,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Signing in…' : 'Sign in')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// First sign-in: set up an authenticator app. 2FA is required for everyone.
class EnrolPage extends StatefulWidget {
  const EnrolPage({super.key});

  @override
  State<EnrolPage> createState() => _EnrolPageState();
}

class _EnrolPageState extends State<EnrolPage> {
  final _code = TextEditingController();
  AuthMFAEnrollResponse? _enrolment;
  Object? _error;
  bool _busy = false;

  GoTrueMFAApi get _mfa => Supabase.instance.client.auth.mfa;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      // Clear any half-finished setup from an earlier visit.
      final factors = await _mfa.listFactors();
      for (final f in factors.all.where((f) => f.status == FactorStatus.unverified)) {
        await _mfa.unenroll(f.id);
      }
      final enrolment = await _mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'IsangoTech',
        friendlyName: 'Authenticator app',
      );
      if (mounted) setState(() => _enrolment = enrolment);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _verify() async {
    final e = _enrolment;
    if (e == null || _code.text.trim().length != 6) return;
    setState(() => _busy = true);
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      await _mfa.challengeAndVerify(factorId: e.id, code: _code.text.trim());
    } catch (err) {
      if (mounted) showError(context, err);
      _code.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _enrolment;
    return AuthCard(
      title: 'Set up two-step sign-in',
      subtitle: 'Every IsangoTech staff account uses an authenticator app (such as Google Authenticator or Microsoft Authenticator) as a second step. You only set this up once.',
      children: [
        if (_error != null) Text(errorMessage(_error!), style: const TextStyle(color: Brand.terracotta)),
        if (e == null && _error == null) const Center(child: CircularProgressIndicator()),
        if (e != null) ...[
          const Text('1. Scan this code with your authenticator app.'),
          const SizedBox(height: 12),
          Center(
            child: QrImageView(data: e.totp!.uri, size: 200, semanticsLabel: 'QR code for your authenticator app'),
          ),
          const SizedBox(height: 8),
          const Text("Can't scan it? Enter this key in the app instead:"),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _grouped(e.totp!.secret),
                  key: const Key('totp-secret'),
                  semanticsLabel: 'Authenticator key: ${e.totp!.secret}',
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 15, letterSpacing: 1),
                ),
              ),
              IconButton(
                tooltip: 'Copy key',
                icon: const Icon(Icons.copy),
                onPressed: () => Clipboard.setData(ClipboardData(text: e.totp!.secret)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('2. Enter the 6-digit code the app shows.'),
          const SizedBox(height: 8),
          _CodeField(controller: _code, onSubmitted: _verify),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _verify,
            child: Text(_busy ? 'Checking…' : 'Turn on two-step sign-in'),
          ),
        ],
        const SizedBox(height: 8),
        TextButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out')),
      ],
    );
  }
}

/// Later sign-ins: enter the code from the authenticator app.
class VerifyPage extends StatefulWidget {
  const VerifyPage({super.key});

  @override
  State<VerifyPage> createState() => _VerifyPageState();
}

class _VerifyPageState extends State<VerifyPage> {
  final _code = TextEditingController();
  bool _busy = false;

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) return;
    setState(() => _busy = true);
    try {
      final mfa = Supabase.instance.client.auth.mfa;
      final factor = (await mfa.listFactors()).totp.firstWhere((f) => f.status == FactorStatus.verified);
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
      await mfa.challengeAndVerify(factorId: factor.id, code: _code.text.trim());
    } catch (e) {
      if (mounted) showError(context, e);
      _code.clear();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthCard(
      title: 'Enter your code',
      subtitle: 'Open your authenticator app and enter the 6-digit code for IsangoTech.',
      children: [
        _CodeField(controller: _code, onSubmitted: _verify),
        const SizedBox(height: 16),
        FilledButton(onPressed: _busy ? null : _verify, child: Text(_busy ? 'Checking…' : 'Continue')),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out')),
      ],
    );
  }
}

/// "ABCDEFGHIJKL" -> "ABCD EFGH IJKL": easier to read and type. Authenticator apps ignore spaces.
String _grouped(String secret) => RegExp('.{1,4}').allMatches(secret).map((m) => m.group(0)).join(' ');

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.onSubmitted});
  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) => TextField(
    key: const Key('totp-code'),
    controller: controller,
    keyboardType: TextInputType.number,
    autofillHints: const [AutofillHints.oneTimeCode],
    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
    decoration: const InputDecoration(labelText: '6-digit code'),
    style: const TextStyle(fontSize: 22, letterSpacing: 6),
    onSubmitted: (_) => onSubmitted(),
  );
}

/// Signed in with 2FA, but not an active team member.
class NoAccessPage extends StatelessWidget {
  const NoAccessPage({super.key});

  @override
  Widget build(BuildContext context) => AuthCard(
    title: 'No portal access',
    subtitle: "You're signed in, but this account isn't set up as an active IsangoTech team member. Ask the admin to add you.",
    children: [FilledButton(onPressed: () => Supabase.instance.client.auth.signOut(), child: const Text('Sign out'))],
  );
}
