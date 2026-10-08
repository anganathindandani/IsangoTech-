import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';

/// Shared shell for the edit dialogs: a form, Cancel and a save button.
class FormDialog extends StatefulWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.onSave,
    this.saveLabel = 'Save',
  });
  final String title;
  final List<Widget> Function(StateSetter setState) fields;
  final Future<void> Function() onSave;
  final String saveLabel;

  @override
  State<FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<FormDialog> {
  final _form = GlobalKey<FormState>();
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await run(context, widget.onSave);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final fields = widget.fields(setState);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (final f in fields) Padding(padding: const EdgeInsets.only(bottom: 12), child: f)],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : widget.saveLabel)),
      ],
    );
  }
}

Future<String?> promptText(BuildContext context, String title, {String label = '', String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: c,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          maxLines: 3,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
      ],
    ),
  );
}

/// Dropdown of growth stages, with "not set" first.
Widget stageDropdown(
  int? value,
  ValueChanged<int?> onChanged, {
  String label = 'Growth stage',
  String none = 'Not set',
}) => DropdownButtonFormField<int?>(
  initialValue: value,
  decoration: InputDecoration(labelText: label),
  items: [
    DropdownMenuItem(value: null, child: Text(none)),
    for (final e in growthStages.entries) DropdownMenuItem(value: e.key, child: Text(stageLabel(e.key))),
  ],
  onChanged: onChanged,
);

Widget industryDropdown(Future<List<Industry>> industries, String? value, ValueChanged<String?> onChanged) =>
    FutureBuilder<List<Industry>>(
      future: industries,
      builder: (context, snap) => DropdownButtonFormField<String?>(
        initialValue: value,
        decoration: const InputDecoration(labelText: 'Industry'),
        items: [
          const DropdownMenuItem(value: null, child: Text('Not set')),
          for (final i in snap.data ?? <Industry>[]) DropdownMenuItem(value: i.id, child: Text(i.name)),
        ],
        onChanged: onChanged,
      ),
    );

class ActivityDialog extends StatelessWidget {
  const ActivityDialog({super.key, this.leadId, this.clientId});
  final String? leadId;
  final String? clientId;

  @override
  Widget build(BuildContext context) {
    var type = 'call';
    final summary = TextEditingController();
    return FormDialog(
      title: 'Log activity',
      fields: (setState) => [
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [for (final e in activityTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => type = v!),
        ),
        TextFormField(
          controller: summary,
          decoration: const InputDecoration(labelText: 'What happened?'),
          maxLines: 3,
          validator: requiredText,
        ),
      ],
      onSave: () => repo.addActivity(leadId: leadId, clientId: clientId, type: type, summary: summary.text.trim()),
    );
  }
}

class EditLeadDialog extends StatelessWidget {
  const EditLeadDialog({super.key, required this.lead});
  final Lead lead;

  @override
  Widget build(BuildContext context) {
    final name = TextEditingController(text: lead.fullName);
    final business = TextEditingController(text: lead.businessName);
    final phone = TextEditingController(text: lead.phone);
    final email = TextEditingController(text: lead.email);
    final pain = TextEditingController(text: lead.biggestPain);
    var industryId = lead.industryId;
    var stage = lead.stageNeeded;
    final industries = repo.industries();
    return FormDialog(
      title: 'Edit lead',
      fields: (setState) => [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: requiredText,
        ),
        TextFormField(
          controller: business,
          decoration: const InputDecoration(labelText: 'Business name'),
        ),
        industryDropdown(industries, industryId, (v) => setState(() => industryId = v)),
        TextFormField(
          controller: phone,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        TextFormField(
          controller: email,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        stageDropdown(stage, (v) => setState(() => stage = v), label: 'Stage needed', none: 'Not sure yet'),
        TextFormField(
          controller: pain,
          decoration: const InputDecoration(labelText: 'Biggest headache'),
          maxLines: 3,
        ),
      ],
      onSave: () => repo.updateLead(lead.id, {
        'full_name': name.text.trim(),
        'business_name': _null(business.text),
        'industry_id': industryId,
        'phone': _null(phone.text),
        'email': _null(email.text),
        'stage_needed': stage,
        'biggest_pain': _null(pain.text),
      }),
    );
  }
}

class ClientDialog extends StatelessWidget {
  const ClientDialog({super.key, this.client, this.onCreated});
  final Client? client;
  final ValueChanged<String>? onCreated;

  @override
  Widget build(BuildContext context) {
    final c = client;
    final name = TextEditingController(text: c?.businessName);
    final address = TextEditingController(text: c?.address);
    final systems = TextEditingController(text: c?.systemsUsed);
    final notes = TextEditingController(text: c?.notes);
    var industryId = c?.industryId;
    var stage = c?.growthStage;
    var status = c?.status ?? 'prospect';
    var review = c?.nextStageReviewDate;
    final industries = repo.industries();
    return FormDialog(
      title: c == null ? 'New client' : 'Edit client',
      fields: (setState) => [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Business name'),
          validator: requiredText,
        ),
        industryDropdown(industries, industryId, (v) => setState(() => industryId = v)),
        stageDropdown(stage, (v) => setState(() => stage = v)),
        DropdownButtonFormField<String>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [for (final e in clientStatuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => status = v!),
        ),
        TextFormField(
          controller: address,
          decoration: const InputDecoration(labelText: 'Address'),
          maxLines: 2,
        ),
        TextFormField(
          controller: systems,
          decoration: const InputDecoration(labelText: 'Systems they use'),
          maxLines: 2,
        ),
        Row(
          children: [
            Expanded(child: Text('Next-stage review: ${review == null ? 'not set' : date(review)}')),
            TextButton(
              onPressed: () async {
                final picked = await pickDate(context, initial: review);
                if (picked != null) setState(() => review = picked);
              },
              child: const Text('Set'),
            ),
          ],
        ),
        TextFormField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'Notes'),
          maxLines: 3,
        ),
      ],
      onSave: () async {
        final values = {
          'business_name': name.text.trim(),
          'industry_id': industryId,
          'growth_stage': stage,
          'status': status,
          'address': _null(address.text),
          'systems_used': _null(systems.text),
          'next_stage_review_date': review == null ? null : isoDate(review!),
          'notes': _null(notes.text),
        };
        if (c == null) {
          onCreated?.call(await repo.addClient(values));
        } else {
          await repo.updateClient(c.id, values);
        }
      },
    );
  }
}

class ContactDialog extends StatelessWidget {
  const ContactDialog({super.key, required this.clientId, this.contact});
  final String clientId;
  final Contact? contact;

  @override
  Widget build(BuildContext context) {
    final c = contact;
    final name = TextEditingController(text: c?.fullName);
    final role = TextEditingController(text: c?.role);
    final phone = TextEditingController(text: c?.phone);
    final email = TextEditingController(text: c?.email);
    var primary = c?.isPrimary ?? false;
    return FormDialog(
      title: c == null ? 'Add contact' : 'Edit contact',
      fields: (setState) => [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: requiredText,
        ),
        TextFormField(
          controller: role,
          decoration: const InputDecoration(labelText: 'Role'),
        ),
        TextFormField(
          controller: phone,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        TextFormField(
          controller: email,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: primary,
          title: const Text('Main contact'),
          onChanged: (v) => setState(() => primary = v ?? false),
        ),
      ],
      onSave: () => repo.saveContact(clientId, {
        'full_name': name.text.trim(),
        'role': _null(role.text),
        'phone': _null(phone.text),
        'email': _null(email.text),
        'is_primary': primary,
      }, id: c?.id),
    );
  }
}

class PackageDialog extends StatelessWidget {
  const PackageDialog({super.key, this.package});
  final Package? package;

  @override
  Widget build(BuildContext context) {
    final p = package;
    final name = TextEditingController(text: p?.name);
    final description = TextEditingController(text: p?.description);
    final price = TextEditingController(text: p == null ? '' : p.price.toString());
    var stage = p?.growthStage;
    var billing = p?.billing ?? 'once_off';
    var active = p?.active ?? true;
    return FormDialog(
      title: p == null ? 'New package' : 'Edit package',
      fields: (setState) => [
        TextFormField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Name'),
          validator: requiredText,
        ),
        stageDropdown(stage, (v) => setState(() => stage = v), none: 'Every stage'),
        TextFormField(
          controller: description,
          decoration: const InputDecoration(labelText: 'Description'),
          maxLines: 3,
        ),
        TextFormField(
          controller: price,
          decoration: const InputDecoration(labelText: 'Price (R)', prefixText: 'R '),
          validator: amountText,
        ),
        DropdownButtonFormField<String>(
          initialValue: billing,
          decoration: const InputDecoration(labelText: 'Billing'),
          items: [for (final e in billingLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => billing = v!),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: active,
          title: const Text('Available on new quotes'),
          onChanged: (v) => setState(() => active = v),
        ),
      ],
      onSave: () => repo.savePackage({
        'name': name.text.trim(),
        'growth_stage': stage,
        'description': _null(description.text),
        'price': parseAmount(price.text),
        'billing': billing,
        'active': active,
      }, id: p?.id),
    );
  }
}

class SlotDialog extends StatelessWidget {
  const SlotDialog({super.key});

  @override
  Widget build(BuildContext context) {
    var day = DateTime.now().add(const Duration(days: 1));
    var start = const TimeOfDay(hour: 9, minute: 0);
    var minutes = 90;
    var mode = 'in_person';
    final location = TextEditingController();
    return FormDialog(
      title: 'Add booking slot',
      saveLabel: 'Add slot',
      fields: (setState) => [
        Row(
          children: [
            Expanded(child: Text('Date: ${date(day)}')),
            TextButton(
              onPressed: () async {
                final picked = await pickDate(context, initial: day);
                if (picked != null) setState(() => day = picked);
              },
              child: const Text('Change'),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text('Starts: ${start.format(context)}')),
            TextButton(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: start);
                if (picked != null) setState(() => start = picked);
              },
              child: const Text('Change'),
            ),
          ],
        ),
        DropdownButtonFormField<int>(
          initialValue: minutes,
          decoration: const InputDecoration(labelText: 'Length'),
          items: [
            for (final m in [30, 60, 90, 120, 180])
              DropdownMenuItem(value: m, child: Text(m < 60 ? '$m minutes' : '${m / 60} hours'.replaceAll('.0', ''))),
          ],
          onChanged: (v) => setState(() => minutes = v!),
        ),
        DropdownButtonFormField<String>(
          initialValue: mode,
          decoration: const InputDecoration(labelText: 'Where'),
          items: const [
            DropdownMenuItem(value: 'in_person', child: Text('In person')),
            DropdownMenuItem(value: 'online', child: Text('Online')),
          ],
          onChanged: (v) => setState(() => mode = v!),
        ),
        if (mode == 'in_person')
          TextFormField(
            controller: location,
            decoration: const InputDecoration(labelText: 'Location (optional)'),
          ),
      ],
      onSave: () {
        final startsAt = DateTime(day.year, day.month, day.day, start.hour, start.minute);
        return repo.addSlot(
          startsAt: startsAt,
          endsAt: startsAt.add(Duration(minutes: minutes)),
          mode: mode,
          location: location.text,
        );
      },
    );
  }
}

class BookAssessmentDialog extends StatelessWidget {
  const BookAssessmentDialog({super.key, this.leadId, this.clientId});
  final String? leadId;
  final String? clientId;

  @override
  Widget build(BuildContext context) {
    String? slotId;
    final slots = repo.slots(status: 'open');
    return FormDialog(
      title: 'Book an AI Readiness Assessment',
      saveLabel: 'Book',
      fields: (setState) => [
        FutureBuilder<List<BookingSlot>>(
          future: slots,
          builder: (context, snap) {
            if (!snap.hasData) return const LinearProgressIndicator();
            if (snap.data!.isEmpty) return const Text('No open slots. Add one on the Assessments page first.');
            return DropdownButtonFormField<String>(
              initialValue: slotId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Time'),
              items: [
                for (final s in snap.data!)
                  DropdownMenuItem(
                    value: s.id,
                    child: Text(s.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => slotId = v),
              validator: (v) => v == null ? 'Pick a time' : null,
            );
          },
        ),
      ],
      onSave: () => repo.bookAssessment(leadId: leadId, clientId: clientId, slotId: slotId!),
    );
  }
}

class AssessmentTile extends StatelessWidget {
  const AssessmentTile(this.assessment, {super.key, required this.onChanged, this.showWho = false});
  final Assessment assessment;
  final VoidCallback onChanged;
  final bool showWho;

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text([if (showWho) a.whoName ?? 'Unknown', dateTime(a.scheduledAt)].join(' · ')),
      subtitle: Text(
        [a.location ?? '', if (a.findings != null) 'Findings recorded'].where((s) => s.isNotEmpty).join(' · '),
      ),
      trailing: StatusChip(assessmentStatuses[a.status] ?? a.status, color: StatusChip.colorFor(a.status)),
      onTap: () async {
        if (await showDialog<bool>(
              context: context,
              builder: (_) => AssessmentDialog(assessment: a),
            ) ==
            true) {
          onChanged();
        }
      },
    );
  }
}

class AssessmentDialog extends StatelessWidget {
  const AssessmentDialog({super.key, required this.assessment});
  final Assessment assessment;

  @override
  Widget build(BuildContext context) {
    final a = assessment;
    var status = a.status;
    var packageId = a.recommendedPackageId;
    final notes = TextEditingController(text: a.notes);
    final findings = TextEditingController(text: a.findings);
    final packages = repo.packages();
    return FormDialog(
      title: 'Assessment · ${dateTime(a.scheduledAt)}',
      fields: (setState) => [
        DropdownButtonFormField<String>(
          initialValue: status,
          decoration: const InputDecoration(labelText: 'Status'),
          items: [for (final e in assessmentStatuses.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => status = v!),
        ),
        TextFormField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'Visit notes'),
          maxLines: 4,
        ),
        TextFormField(
          controller: findings,
          decoration: const InputDecoration(labelText: 'Findings'),
          maxLines: 4,
        ),
        FutureBuilder<List<Package>>(
          future: packages,
          builder: (context, snap) => DropdownButtonFormField<String?>(
            initialValue: packageId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Recommended package'),
            items: [
              const DropdownMenuItem(value: null, child: Text('None yet')),
              for (final p in snap.data ?? <Package>[]) DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => packageId = v),
          ),
        ),
        if (status == 'cancelled' && a.status != 'cancelled')
          const Text('Cancelling frees the booking slot for someone else.'),
      ],
      onSave: () => repo.updateAssessment(a.id, {
        'status': status,
        'notes': _null(notes.text),
        'findings': _null(findings.text),
        'recommended_package_id': packageId,
      }),
    );
  }
}

class PaymentDialog extends StatelessWidget {
  const PaymentDialog({super.key, required this.invoice});
  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final amount = TextEditingController(text: invoice.balance.toStringAsFixed(2));
    final reference = TextEditingController();
    var paidOn = DateTime.now();
    var method = 'eft';
    return FormDialog(
      title: 'Record payment',
      saveLabel: 'Record payment',
      fields: (setState) => [
        Text('Still owed: ${money(invoice.balance)}'),
        TextFormField(
          controller: amount,
          decoration: const InputDecoration(labelText: 'Amount', prefixText: 'R '),
          validator: amountText,
        ),
        Row(
          children: [
            Expanded(child: Text('Paid on ${date(paidOn)}')),
            TextButton(
              onPressed: () async {
                final picked = await pickDate(context, initial: paidOn);
                if (picked != null) setState(() => paidOn = picked);
              },
              child: const Text('Change'),
            ),
          ],
        ),
        DropdownButtonFormField<String>(
          initialValue: method,
          decoration: const InputDecoration(labelText: 'Method'),
          items: [for (final e in paymentMethods.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => method = v!),
        ),
        TextFormField(
          controller: reference,
          decoration: const InputDecoration(labelText: 'Reference (optional)'),
        ),
      ],
      onSave: () => repo.recordPayment(
        invoice.id,
        amount: parseAmount(amount.text),
        paidOn: paidOn,
        method: method,
        reference: reference.text,
      ),
    );
  }
}

class NewInvoiceDialog extends StatelessWidget {
  const NewInvoiceDialog({super.key, this.clientId, required this.onCreated});
  final String? clientId;
  final ValueChanged<String> onCreated;

  @override
  Widget build(BuildContext context) {
    var selectedClient = clientId;
    var type = 'custom';
    final amount = TextEditingController();
    final description = TextEditingController();
    final clients = repo.clients();
    return FormDialog(
      title: 'New invoice',
      saveLabel: 'Create draft',
      fields: (setState) => [
        FutureBuilder<List<Client>>(
          future: clients,
          builder: (context, snap) => DropdownButtonFormField<String>(
            initialValue: selectedClient,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Client'),
            items: [
              for (final c in snap.data ?? <Client>[]) DropdownMenuItem(value: c.id, child: Text(c.businessName)),
            ],
            onChanged: (v) => setState(() => selectedClient = v),
            validator: (v) => v == null ? 'Choose a client' : null,
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [for (final e in invoiceTypes.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => type = v!),
        ),
        TextFormField(
          controller: description,
          decoration: const InputDecoration(labelText: 'Description'),
        ),
        TextFormField(
          controller: amount,
          decoration: const InputDecoration(labelText: 'Amount', prefixText: 'R '),
          validator: amountText,
        ),
      ],
      onSave: () async => onCreated(
        await repo.createInvoice(
          clientId: selectedClient!,
          type: type,
          amount: parseAmount(amount.text),
          description: description.text,
        ),
      ),
    );
  }
}

class QuoteLineDialog extends StatelessWidget {
  const QuoteLineDialog({super.key, required this.quoteId, this.line, this.nextSortOrder = 0});
  final String quoteId;
  final QuoteLine? line;
  final int nextSortOrder;

  @override
  Widget build(BuildContext context) {
    final l = line;
    String? packageId = l?.packageId;
    final description = TextEditingController(text: l?.description);
    final quantity = TextEditingController(text: l == null ? '1' : '${l.quantity}');
    final price = TextEditingController(text: l == null ? '' : '${l.unitPrice}');
    var billing = l?.billing ?? 'once_off';
    final packages = repo.packages(activeOnly: true);
    return FormDialog(
      title: l == null ? 'Add line' : 'Edit line',
      fields: (setState) => [
        if (l == null)
          FutureBuilder<List<Package>>(
            future: packages,
            builder: (context, snap) => DropdownButtonFormField<String?>(
              initialValue: packageId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'From the price list'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Custom line')),
                for (final p in snap.data ?? <Package>[])
                  DropdownMenuItem(
                    value: p.id,
                    child: Text('${p.name} · ${money(p.price)}${p.billing == 'monthly' ? ' / month' : ''}'),
                  ),
              ],
              onChanged: (v) => setState(() {
                packageId = v;
                final p = snap.data!.where((p) => p.id == v).firstOrNull;
                if (p != null) {
                  description.text = p.name;
                  price.text = '${p.price}';
                  billing = p.billing;
                }
              }),
            ),
          ),
        TextFormField(
          controller: description,
          decoration: const InputDecoration(labelText: 'Description'),
          validator: requiredText,
          maxLines: 2,
        ),
        TextFormField(
          controller: quantity,
          decoration: const InputDecoration(labelText: 'Quantity'),
          validator: amountText,
        ),
        TextFormField(
          controller: price,
          decoration: const InputDecoration(labelText: 'Unit price', prefixText: 'R '),
          validator: amountText,
        ),
        DropdownButtonFormField<String>(
          key: ValueKey(billing),
          initialValue: billing,
          decoration: const InputDecoration(labelText: 'Billing'),
          items: [for (final e in billingLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => billing = v!),
        ),
      ],
      onSave: () => l == null
          ? repo.addQuoteLine(
              quoteId,
              packageId: packageId,
              description: description.text.trim(),
              quantity: parseAmount(quantity.text),
              unitPrice: parseAmount(price.text),
              billing: billing,
              sortOrder: nextSortOrder,
            )
          : repo.updateQuoteLine(l.id, {
              'description': description.text.trim(),
              'quantity': parseAmount(quantity.text),
              'unit_price': parseAmount(price.text),
              'billing': billing,
            }),
    );
  }
}

String? _null(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
