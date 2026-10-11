import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../data/models.dart';
import '../widgets/ui.dart';

const _industries = {
  'salon': 'Salon or beauty',
  'guesthouse': 'Guesthouse or B&B',
  'restaurant': 'Restaurant or food business',
  'caterer': 'Caterer',
  'other': 'Other small business',
};
const _products = {'assistant': 'WhatsApp Assistant', 'portal': 'Business Portal'};
const _statuses = {'onboarding': 'Onboarding', 'active': 'Active', 'paused': 'Paused', 'closed': 'Closed'};

/// IsangoTech admins only: every client business, adding new ones with their
/// owner, and the plan details owners can't change themselves.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _add() async {
    final result = await showDialog<_Created>(context: context, builder: (_) => const _BusinessDialog());
    if (result == null || !mounted) return;
    _reload();
    await _showLink(
      context,
      title: '${result.businessName} is set up',
      intro: result.newLogin
          ? 'Send ${result.ownerName} this link on WhatsApp. It signs them in once so they can choose a password.'
          : '${result.ownerName} already had a login, so they can sign in as usual. If they need a new password, send '
                'them this link.',
      ownerName: result.ownerName,
      link: result.link,
    );
  }

  Future<void> _edit(AdminBusiness b) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _BusinessDialog(existing: b),
    );
    if (saved == true) _reload();
  }

  Future<void> _newLink(String name, String email) async {
    String? link;
    final ok = await run(context, () async => link = await repo.setupLink(email));
    if (!ok || !mounted) return;
    await _showLink(
      context,
      title: 'New setup link for $name',
      intro: 'It signs them in once so they can choose a new password.',
      ownerName: name,
      link: link!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      maxWidth: 1000,
      children: [
        PageHeader(
          'Businesses',
          subtitle: 'Every client business. You see their plan and owners, not their customers or chats.',
          actions: [
            FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('Add a business')),
          ],
        ),
        Loader<List<AdminBusiness>>(
          key: _key,
          load: repo.adminBusinesses,
          builder: (context, list, _) => list.isEmpty
              ? const Card(child: EmptyState('No businesses yet. Add your first client.'))
              : Column(
                  children: [
                    for (final b in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Section(
                          title: b.name,
                          trailing: TextButton.icon(
                            onPressed: () => _edit(b),
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit'),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  StatusChip(_statuses[b.status] ?? b.status, color: _statusColor(b.status)),
                                  for (final p in b.products) StatusChip(_products[p] ?? p),
                                  StatusChip(b.assistantEnabled ? 'Assistant on' : 'Assistant off'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                [
                                  _industries[b.industry] ?? b.industry,
                                  '${b.allowance} conversations a month',
                                  b.whatsappDisplayNumber ??
                                      (b.whatsappPhoneNumberId == null
                                          ? 'No WhatsApp number yet'
                                          : 'WhatsApp connected'),
                                ].join(' · '),
                              ),
                              const SizedBox(height: 8),
                              for (final o in b.owners)
                                Row(
                                  children: [
                                    Expanded(child: Text('Owner: ${o.name} (${o.email})')),
                                    TextButton(
                                      onPressed: () => _newLink(o.name, o.email),
                                      child: const Text('New setup link'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

Color? _statusColor(String status) => switch (status) {
  'active' => StatusChip.colorFor('completed'),
  'onboarding' => StatusChip.colorFor('pending'),
  'paused' || 'closed' => StatusChip.colorFor('cancelled'),
  _ => null,
};

/// Shows a setup link with buttons to copy it, or a ready-to-send WhatsApp message.
Future<void> _showLink(
  BuildContext context, {
  required String title,
  required String intro,
  required String ownerName,
  required String link,
}) {
  final message =
      'Hi ${ownerName.split(' ').first}, welcome to IsangoTech! Open this link to choose your password for your '
      'business dashboard: $link\n\nThe link works once, so open it soon. After that, sign in at app.isangotech.co.za.';
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(intro),
            const SizedBox(height: 12),
            SelectableText(link, style: const TextStyle(fontSize: 12.5)),
            const SizedBox(height: 12),
            const Text(
              'The link works once and expires after an hour, unless you set a longer time in Supabase.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: link));
            showDone(ctx, 'Link copied.');
          },
          child: const Text('Copy link'),
        ),
        FilledButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: message));
            showDone(ctx, 'Message copied. Paste it into WhatsApp.');
          },
          child: const Text('Copy WhatsApp message'),
        ),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
      ],
    ),
  );
}

class _Created {
  _Created(this.businessName, this.ownerName, this.link, this.newLogin);
  final String businessName;
  final String ownerName;
  final String link;
  final bool newLogin;
}

/// Adding a business with its owner, or editing an existing one's plan.
class _BusinessDialog extends StatefulWidget {
  const _BusinessDialog({this.existing});
  final AdminBusiness? existing;

  @override
  State<_BusinessDialog> createState() => _BusinessDialogState();
}

class _BusinessDialogState extends State<_BusinessDialog> {
  final _form = GlobalKey<FormState>();
  late final AdminBusiness b =
      widget.existing ??
      AdminBusiness(
        id: '',
        name: '',
        industry: 'salon',
        status: 'onboarding',
        products: ['assistant'],
        allowance: 300,
        assistantEnabled: false,
        owners: const [],
      );
  String _ownerName = '';
  String _ownerEmail = '';
  bool _busy = false;

  bool get _adding => widget.existing == null;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (b.products.isEmpty) {
      showError(context, StateError('Choose at least one product.'));
      return;
    }
    setState(() => _busy = true);
    if (_adding) {
      ({String setupLink, bool newLogin})? result;
      final ok = await run(context, () async => result = await repo.onboard(b, _ownerName.trim(), _ownerEmail.trim()));
      if (!mounted) return;
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, _Created(b.name.trim(), _ownerName.trim(), result!.setupLink, result!.newLogin));
    } else {
      final ok = await run(context, () => repo.adminUpdateBusiness(b), done: 'Saved.');
      if (!mounted) return;
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_adding ? 'Add a business' : 'Edit ${b.name}'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  initialValue: b.name,
                  autofocus: _adding,
                  decoration: const InputDecoration(labelText: 'Business name'),
                  validator: requiredText,
                  onChanged: (v) => b.name = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: b.industry,
                  decoration: const InputDecoration(labelText: 'Kind of business'),
                  items: [for (final e in _industries.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => b.industry = v ?? b.industry,
                ),
                const SizedBox(height: 12),
                const Text('Products'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in _products.entries)
                      FilterChip(
                        label: Text(e.value),
                        selected: b.products.contains(e.key),
                        onSelected: (on) => setState(
                          () => b.products = on ? [...b.products, e.key] : [...b.products.where((p) => p != e.key)],
                        ),
                      ),
                  ],
                ),
                if (!_adding) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: b.status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [for (final e in _statuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => b.status = v ?? b.status,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '${b.allowance}',
                  decoration: const InputDecoration(labelText: 'WhatsApp conversations included a month'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => int.tryParse(v ?? '') == null ? 'Enter a number' : null,
                  onChanged: (v) => b.allowance = int.tryParse(v) ?? b.allowance,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: b.whatsappPhoneNumberId ?? '',
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp phone number ID (optional)',
                    helperText: "From Meta: WhatsApp → API Setup. Add it later if it isn't ready.",
                  ),
                  onChanged: (v) => b.whatsappPhoneNumberId = v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: b.whatsappDisplayNumber ?? '',
                  decoration: const InputDecoration(labelText: 'Their WhatsApp number, as customers see it (optional)'),
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => b.whatsappDisplayNumber = v,
                ),
                if (_adding) ...[
                  const Divider(height: 32),
                  Text('Owner', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  TextFormField(
                    decoration: const InputDecoration(labelText: "Owner's name"),
                    validator: requiredText,
                    onChanged: (v) => _ownerName = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: "Owner's email",
                      helperText: 'They sign in with this. No email is sent; you share a setup link on WhatsApp.',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((v ?? '').trim())
                        ? null
                        : "That email address doesn't look right",
                    onChanged: (v) => _ownerEmail = v,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : (_adding ? 'Add business' : 'Save')),
        ),
      ],
    );
  }
}
