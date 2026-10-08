import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  /// null = all open leads.
  String? _stage;
  String _search = '';
  Key _listKey = UniqueKey();

  void _reload() => setState(() => _listKey = UniqueKey());

  Future<void> _quickAdd() async {
    final id = await showDialog<String>(context: context, builder: (_) => const QuickAddLeadDialog());
    if (id != null && mounted) context.go('/leads/$id');
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        PageHeader(
          'Leads',
          subtitle: 'Every enquiry, from first message to won or lost.',
          actions: [
            FilledButton.icon(onPressed: _quickAdd, icon: const Icon(Icons.add), label: const Text('Quick add')),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Open'),
              selected: _stage == null,
              onSelected: (_) => setState(() => _stage = null),
            ),
            for (final e in pipelineStages.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _stage == e.key,
                onSelected: (_) => setState(() => _stage = e.key),
              ),
          ],
        ),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search name, business, phone or email',
          ),
          onSubmitted: (v) => setState(() => _search = v),
        ),
        Card(
          semanticContainer: false,

          child: Loader<List<Lead>>(
            key: ValueKey('$_listKey$_stage$_search'),
            load: () => repo.leads(pipelineStage: _stage, openOnly: _stage == null, search: _search),
            builder: (context, leads, _) => leads.isEmpty
                ? const EmptyState(
                    'No leads here yet. Website enquiries appear automatically; use Quick add for WhatsApp, walk-in and phone enquiries.',
                  )
                : Column(children: [for (final l in leads) LeadTile(l, onReturn: _reload)]),
          ),
        ),
      ],
    );
  }
}

class LeadTile extends StatelessWidget {
  const LeadTile(this.lead, {super.key, this.onReturn});
  final Lead lead;
  final VoidCallback? onReturn;

  @override
  Widget build(BuildContext context) {
    final followUp = lead.nextFollowUp;
    final due = followUp != null && !followUp.isAfter(DateTime.now());
    return ListTile(
      title: Text(lead.displayName),
      subtitle: Text(
        [
          leadSources[lead.source] ?? lead.source,
          if (lead.stageNeeded != null) stageLabel(lead.stageNeeded),
          if (followUp != null) 'Follow up ${date(followUp)}',
        ].join(' · '),
        style: TextStyle(color: due ? const Color(0xFFB5523B) : null),
      ),
      trailing: StatusChip(
        pipelineStages[lead.pipelineStage] ?? lead.pipelineStage,
        color: StatusChip.colorFor(lead.pipelineStage),
      ),
      onTap: () async {
        await context.push('/leads/${lead.id}');
        onReturn?.call();
      },
    );
  }
}

/// WhatsApp, walk-in and phone enquiries go in here until the WhatsApp
/// Business API is connected.
class QuickAddLeadDialog extends StatefulWidget {
  const QuickAddLeadDialog({super.key});

  @override
  State<QuickAddLeadDialog> createState() => _QuickAddLeadDialogState();
}

class _QuickAddLeadDialogState extends State<QuickAddLeadDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _pain = TextEditingController();
  String _source = 'whatsapp';
  String? _industryId;
  int? _stage;
  bool _consent = false;
  bool _whatsapp = false;
  bool _busy = false;
  late final Future<List<Industry>> _industries = repo.industries();

  Future<void> _save() async {
    if (!_form.currentState!.validate() || !_consent) return;
    setState(() => _busy = true);
    try {
      final id = await repo.addLead(
        fullName: _name.text.trim(),
        businessName: _business.text,
        industryId: _industryId,
        phone: _phone.text,
        email: _email.text,
        source: _source,
        stageNeeded: _stage,
        biggestPain: _pain.text,
        whatsappOptIn: _whatsapp,
      );
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quick add lead'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _source,
                  decoration: const InputDecoration(labelText: 'How did they contact us?'),
                  items: [
                    for (final e in leadSources.entries.where((e) => e.key != 'website_form'))
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _source = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: requiredText,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _business,
                  decoration: const InputDecoration(labelText: 'Business name'),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<Industry>>(
                  future: _industries,
                  builder: (context, snap) => DropdownButtonFormField<String?>(
                    initialValue: _industryId,
                    decoration: const InputDecoration(labelText: 'Industry'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Not sure')),
                      for (final i in snap.data ?? <Industry>[]) DropdownMenuItem(value: i.id, child: Text(i.name)),
                    ],
                    onChanged: (v) => setState(() => _industryId = v),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'Phone or WhatsApp number'),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty && _email.text.trim().isEmpty ? 'Add a phone number or an email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  initialValue: _stage,
                  decoration: const InputDecoration(labelText: 'Growth stage they need'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Not sure yet')),
                    for (final e in growthStages.entries)
                      DropdownMenuItem(value: e.key, child: Text(stageLabel(e.key))),
                  ],
                  onChanged: (v) => setState(() => _stage = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pain,
                  decoration: const InputDecoration(labelText: 'Biggest headache'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _consent,
                  onChanged: (v) => setState(() => _consent = v ?? false),
                  title: const Text('They agreed we may use these details to respond to their enquiry'),
                  subtitle: _consent
                      ? null
                      : const Text('Required by POPIA', style: TextStyle(color: Color(0xFFB5523B))),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _whatsapp,
                  onChanged: (v) => setState(() => _whatsapp = v ?? false),
                  title: const Text('They agreed to be contacted on WhatsApp'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy || !_consent ? null : _save, child: Text(_busy ? 'Saving…' : 'Add lead')),
      ],
    );
  }
}
