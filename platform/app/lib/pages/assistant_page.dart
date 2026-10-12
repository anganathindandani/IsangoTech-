import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';

/// Everything the Assistant works from: whether it's on, opening hours, how it
/// talks, booking rules, services and prices, staff, and the business's answers.
class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context);
    return PageBody(
      maxWidth: 900,
      children: [
        const PageHeader(
          'Assistant',
          subtitle: 'The Assistant only quotes what is here, so keep prices and hours up to date.',
        ),
        _SettingsSection(key: ValueKey('settings${me.businessId}'), businessId: me.businessId),
        _ServicesSection(key: ValueKey('services${me.businessId}'), businessId: me.businessId),
        _StaffSection(key: ValueKey('staff${me.businessId}'), businessId: me.businessId),
        _AnswersSection(key: ValueKey('answers${me.businessId}'), businessId: me.businessId),
      ],
    );
  }
}

// Settings ------------------------------------------------------------------

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({super.key, required this.businessId});
  final String businessId;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  late Future<AssistantSettings> _future = repo.settings(widget.businessId);
  AssistantSettings? _s;
  bool _saving = false;

  Future<void> _save() async {
    final s = _s!;
    if (s.languages.isEmpty) {
      showError(context, StateError('Choose at least one language.'));
      return;
    }
    if (s.remindersEnabled && (s.reminderTemplate ?? '').trim().isEmpty) {
      showError(context, StateError("Add your reminder template's name, or switch reminders off."));
      return;
    }
    setState(() => _saving = true);
    await run(
      context,
      () => repo.saveSettings(widget.businessId, s),
      done: 'Saved. The Assistant uses this from the next message.',
    );
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickTime(String dayKey, int edge) async {
    final span = _s!.openingHours[dayKey]!.first;
    final parts = span[edge].split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (picked == null) return;
    final text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    if ((edge == 0 && text.compareTo(span[1]) >= 0) || (edge == 1 && text.compareTo(span[0]) <= 0)) {
      if (mounted) showError(context, StateError('Closing time must be after opening time.'));
      return;
    }
    setState(() => span[edge] = text);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssistantSettings>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Section(
            title: 'Settings',
            child: Column(
              children: [
                Text(errorMessage(snap.error!)),
                TextButton(
                  onPressed: () => setState(() => _future = repo.settings(widget.businessId)),
                  child: const Text('Try again'),
                ),
              ],
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final s = _s ??= snap.data!;
        final narrow = MediaQuery.sizeOf(context).width < 600;
        return Section(
          title: 'Settings',
          trailing: FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save')),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('The Assistant answers WhatsApp messages'),
                subtitle: Text(
                  s.assistantEnabled
                      ? 'On. Messages are answered straight away; chats you take over stay with you.'
                      : 'Off. Messages are saved here, but nobody replies automatically.',
                ),
                value: s.assistantEnabled,
                onChanged: (v) => setState(() => s.assistantEnabled = v),
              ),
              const Divider(height: 32),
              Text('Opening hours', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              for (final (key, label) in weekdays)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: narrow ? 4 : 8,
                    children: [
                      // Short day names on phones, so a day's hours fit on one line.
                      SizedBox(width: narrow ? 40 : 100, child: Text(narrow ? label.substring(0, 3) : label)),
                      Switch(
                        value: (s.openingHours[key] ?? []).isNotEmpty,
                        onChanged: (open) => setState(
                          () => s.openingHours[key] = open
                              ? [
                                  ['08:00', '17:00'],
                                ]
                              : [],
                        ),
                      ),
                      if ((s.openingHours[key] ?? []).isEmpty)
                        const Text('Closed', style: TextStyle(color: Colors.black54))
                      else ...[
                        OutlinedButton(onPressed: () => _pickTime(key, 0), child: Text(s.openingHours[key]!.first[0])),
                        const Text('to'),
                        OutlinedButton(onPressed: () => _pickTime(key, 1), child: Text(s.openingHours[key]!.first[1])),
                      ],
                    ],
                  ),
                ),
              const Divider(height: 32),
              Text('How it talks', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in languages.entries)
                    FilterChip(
                      label: Text(e.value),
                      selected: s.languages.contains(e.key),
                      onSelected: (on) => setState(
                        () => on ? s.languages = [...s.languages, e.key] : s.languages = [...s.languages]
                          ..remove(e.key),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: s.tone,
                decoration: const InputDecoration(
                  labelText: 'Tone',
                  helperText: 'For example: Warm and friendly, a little playful',
                ),
                onChanged: (v) => s.tone = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: s.policies,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Policies',
                  helperText: 'Cancellations, lateness, deposits, children, parking: in your own words',
                ),
                onChanged: (v) => s.policies = v,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: s.handoverTopics,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Always pass these to a person',
                  helperText: 'Complaints, refunds and requests for a person are always handed over',
                ),
                onChanged: (v) => s.handoverTopics = v,
              ),
              const Divider(height: 32),
              Text('Bookings', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  _NumberField(
                    label: 'Notice to book (hours)',
                    value: s.minBookingNoticeHours,
                    onChanged: (v) => s.minBookingNoticeHours = v,
                  ),
                  _NumberField(
                    label: 'Notice to change or cancel (hours)',
                    value: s.changeNoticeHours,
                    onChanged: (v) => s.changeNoticeHours = v,
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ask for a deposit'),
                value: s.depositRequired,
                onChanged: (v) => setState(() => s.depositRequired = v),
              ),
              if (s.depositRequired)
                _NumberField(
                  label: 'Deposit (% of the price)',
                  value: s.depositPercent.toInt(),
                  max: 100,
                  onChanged: (v) => s.depositPercent = v,
                ),
              const Divider(height: 32),
              Text('Reminders', style: Theme.of(context).textTheme.titleSmall),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Send booking reminders on WhatsApp'),
                subtitle: const Text(
                  'To customers who booked on WhatsApp or agreed to updates. One reminder per booking; a moved '
                  'booking gets a new one.',
                ),
                value: s.remindersEnabled,
                onChanged: (v) => setState(() => s.remindersEnabled = v),
              ),
              if (s.remindersEnabled) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _NumberField(
                      label: 'Hours before the booking',
                      value: s.reminderHoursBefore,
                      min: 1,
                      max: 72,
                      onChanged: (v) => s.reminderHoursBefore = v,
                    ),
                    SizedBox(
                      width: 260,
                      child: TextFormField(
                        initialValue: s.reminderTemplate ?? '',
                        decoration: const InputDecoration(labelText: 'Template name, as approved by Meta'),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: (v) => (v ?? '').trim().isEmpty || RegExp(r'^[a-z0-9_]+$').hasMatch(v!.trim())
                            ? null
                            : 'Small letters, numbers and _ only',
                        onChanged: (v) => s.reminderTemplate = v,
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        initialValue: s.reminderTemplateLanguage,
                        decoration: const InputDecoration(labelText: 'Language', helperText: 'e.g. en'),
                        onChanged: (v) => s.reminderTemplateLanguage = v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _TemplateHelp(),
              ],
              const Divider(height: 32),
              Text('Privacy', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: s.privacyNoticeUrl ?? '',
                decoration: const InputDecoration(
                  labelText: 'Your privacy notice (web address)',
                  helperText: "New customers get this link with the Assistant's first reply",
                ),
                keyboardType: TextInputType.url,
                onChanged: (v) => s.privacyNoticeUrl = v,
              ),
              const SizedBox(height: 12),
              _NumberField(
                label: 'Delete chats after (months)',
                value: s.messageRetentionMonths,
                min: 1,
                max: 60,
                onChanged: (v) => s.messageRetentionMonths = v,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The reminder template to submit to Meta, so its {{1}} to {{5}} match what the reminders fill in.
class _TemplateHelp extends StatelessWidget {
  const _TemplateHelp();

  static const body =
      'Hi {{1}}, this is a reminder of your {{2}} at {{3}} on {{4}} at {{5}}. '
      'Reply to this message if you need to change or cancel.';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF5EBDD), borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "WhatsApp only allows reminders that Meta has approved. In Meta's WhatsApp Manager, create a template "
            'named booking_reminder, category Utility, with this text:',
          ),
          const SizedBox(height: 8),
          const SelectableText(body, style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text(
            '{{1}} is the customer\'s first name, {{2}} the service, {{3}} your business, {{4}} the day and {{5}} '
            'the time. Approval usually takes minutes to a day.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: body));
              showDone(context, 'Template text copied.');
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy the text'),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.value, required this.onChanged, this.min = 0, this.max = 720});
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 260,
    child: TextFormField(
      initialValue: '$value',
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) {
        final n = int.tryParse(v ?? '');
        return n == null || n < min || n > max ? 'Between $min and $max' : null;
      },
      onChanged: (v) {
        final n = int.tryParse(v);
        if (n != null && n >= min && n <= max) onChanged(n);
      },
    ),
  );
}

// Services ------------------------------------------------------------------

class _ServicesSection extends StatefulWidget {
  const _ServicesSection({super.key, required this.businessId});
  final String businessId;

  @override
  State<_ServicesSection> createState() => _ServicesSectionState();
}

class _ServicesSectionState extends State<_ServicesSection> {
  Key _key = UniqueKey();

  Future<void> _edit([Service? existing]) async {
    final s = existing ?? Service(name: '');
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add a service' : 'Edit service'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: s.name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: requiredText,
                    onChanged: (v) => s.name = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: s.description,
                    decoration: const InputDecoration(labelText: 'Description (optional)'),
                    onChanged: (v) => s.description = v,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: s.price?.toString() ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Price in rand',
                      helperText: 'Leave empty for "price on request"',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => v == null || v.trim().isEmpty ? null : amountText(v),
                    onChanged: (v) => s.price = v.trim().isEmpty || amountText(v) != null ? null : parseAmount(v),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('This is a starting price ("from R…")'),
                    value: s.priceFrom,
                    onChanged: (v) => setState(() => s.priceFrom = v ?? false),
                  ),
                  TextFormField(
                    initialValue: s.durationMinutes?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'How long it takes (minutes)'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (v) => s.durationMinutes = int.tryParse(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Offered'),
                    subtitle: const Text('Switch off to stop the Assistant offering it'),
                    value: s.active,
                    onChanged: (v) => setState(() => s.active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                final ok = await run(ctx, () => repo.saveService(widget.businessId, s));
                if (ok && ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Services and prices',
      trailing: TextButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add')),
      child: Loader<List<Service>>(
        key: _key,
        load: () => repo.services(widget.businessId),
        builder: (context, list, _) => list.isEmpty
            ? const EmptyState('No services yet. Add what you offer, so the Assistant can quote and book it.')
            : Column(
                children: [
                  for (final s in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(s.name, style: TextStyle(color: s.active ? null : Colors.black45)),
                      subtitle: Text(
                        [
                          s.priceLabel,
                          if (s.durationMinutes != null) '${s.durationMinutes} min',
                          if (!s.active) 'Not offered',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(s),
                    ),
                ],
              ),
      ),
    );
  }
}

// Staff ---------------------------------------------------------------------

class _StaffSection extends StatefulWidget {
  const _StaffSection({super.key, required this.businessId});
  final String businessId;

  @override
  State<_StaffSection> createState() => _StaffSectionState();
}

class _StaffSectionState extends State<_StaffSection> {
  Key _key = UniqueKey();

  Future<void> _edit([StaffMember? existing]) async {
    final m = existing ?? StaffMember(fullName: '');
    final form = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(existing == null ? 'Add a staff member' : 'Edit staff member'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    initialValue: m.fullName,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Name customers know them by'),
                    validator: requiredText,
                    onChanged: (v) => m.fullName = v,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Taking bookings'),
                    value: m.active,
                    onChanged: (v) => setState(() => m.active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                final ok = await run(ctx, () => repo.saveStaff(widget.businessId, m));
                if (ok && ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Staff',
      trailing: TextButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add')),
      child: Loader<List<StaffMember>>(
        key: _key,
        load: () => repo.staff(widget.businessId),
        builder: (context, list, _) => list.isEmpty
            ? const EmptyState('No staff added. Without staff, bookings are taken for any time you\'re open.')
            : Column(
                children: [
                  for (final m in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(m.fullName, style: TextStyle(color: m.active ? null : Colors.black45)),
                      subtitle: m.active ? null : const Text('Not taking bookings'),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(m),
                    ),
                ],
              ),
      ),
    );
  }
}

// Answers -------------------------------------------------------------------

class _AnswersSection extends StatefulWidget {
  const _AnswersSection({super.key, required this.businessId});
  final String businessId;

  @override
  State<_AnswersSection> createState() => _AnswersSectionState();
}

class _AnswersSectionState extends State<_AnswersSection> {
  Key _key = UniqueKey();

  Future<void> _edit([KnowledgeItem? existing]) async {
    final k = existing ?? KnowledgeItem(question: '', answer: '');
    final form = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add an answer' : 'Edit answer'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: k.question,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    helperText: 'For example: Where can I park?',
                  ),
                  validator: requiredText,
                  onChanged: (v) => k.question = v,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: k.answer,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Answer'),
                  validator: requiredText,
                  onChanged: (v) => k.answer = v,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                final ok = await run(ctx, () => repo.deleteKnowledge(existing.id!));
                if (ok && ctx.mounted) Navigator.pop(ctx, 'deleted');
              },
              child: const Text('Delete'),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!form.currentState!.validate()) return;
              final ok = await run(ctx, () => repo.saveKnowledge(widget.businessId, k));
              if (ok && ctx.mounted) Navigator.pop(ctx, 'saved');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Answers the Assistant can give',
      trailing: TextButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add')),
      child: Loader<List<KnowledgeItem>>(
        key: _key,
        load: () => repo.knowledge(widget.businessId),
        builder: (context, list, _) => list.isEmpty
            ? const EmptyState('No answers yet. Add things customers often ask: parking, directions, what to bring.')
            : Column(
                children: [
                  for (final k in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(k.question),
                      subtitle: Text(k.answer, maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _edit(k),
                    ),
                ],
              ),
      ),
    );
  }
}
