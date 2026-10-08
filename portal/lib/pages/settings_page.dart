import 'dart:convert';

import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// Friendly names for the settings the spec defines; anything else shows its key.
const _labels = {
  'quote_approval_amount': 'Quote approval amount (R, first-year value)',
  'quote_valid_days': 'Quotes valid for (days)',
  'invoice_due_days': 'Invoices due after (days)',
  'currency': 'Currency',
  'vat_registered': 'Registered VAT vendor',
  'vat_rate': 'VAT rate',
  'privacy_policy_version': 'Current privacy policy version',
  'lead_retention_months': 'Anonymise unconverted leads after (months)',
  'lost_prospect_retention_months': 'Anonymise lost prospects after (months)',
  'booking_min_notice_hours': 'Website bookings need notice of (hours)',
  'booking_window_days': 'Website shows slots up to (days ahead)',
  'next_stage_review_months': 'Next-stage review after go-live (months)',
  'invoice_payment_details': 'Payment details on invoices',
};

class _SettingsPageState extends State<SettingsPage> {
  Key _key = UniqueKey();

  Future<void> _edit(Setting s) async {
    final controller = TextEditingController(text: s.value is String ? s.value as String : jsonEncode(s.value));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_labels[s.key] ?? s.key),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.description != null) Text(s.description!),
              const SizedBox(height: 12),
              if (s.value is bool)
                StatefulBuilder(
                  builder: (ctx, setState) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Yes'),
                    value: controller.text == 'true',
                    onChanged: (v) => setState(() => controller.text = '$v'),
                  ),
                )
              else
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: s.value is num ? TextInputType.number : TextInputType.multiline,
                  maxLines: s.value is String ? 4 : 1,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              final dynamic value = s.value is num
                  ? num.tryParse(text)
                  : s.value is bool
                  ? text == 'true'
                  : text;
              if (value == null || (value is String && value.isEmpty && s.key != 'invoice_payment_details')) {
                showError(ctx, StateError('Enter a value'));
                return;
              }
              final ok = await run(ctx, () => repo.updateSetting(s.key, value));
              if (ok && ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved == true) setState(() => _key = UniqueKey());
  }

  String _display(dynamic v) => switch (v) {
    bool b => b ? 'Yes' : 'No',
    String t when t.isEmpty => 'Not set',
    String t when t.length > 30 => '${t.substring(0, 30)}…',
    _ => '$v',
  };

  @override
  Widget build(BuildContext context) {
    return PageBody(
      maxWidth: 800,
      children: [
        const PageHeader(
          'Settings',
          subtitle: 'Business rules the portal and website follow. Every change is recorded in the audit log.',
        ),
        Card(
          semanticContainer: false,

          child: Loader<List<Setting>>(
            key: _key,
            load: repo.settings,
            builder: (context, list, _) => Column(
              children: [
                for (final s in list)
                  ListTile(
                    title: Text(_labels[s.key] ?? s.key),
                    subtitle: s.updatedAt == null ? null : Text('Changed ${date(s.updatedAt)}'),
                    trailing: Text(_display(s.value), style: const TextStyle(fontWeight: FontWeight.w500)),
                    onTap: () => _edit(s),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
