import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';

class AuditPage extends StatefulWidget {
  const AuditPage({super.key});

  @override
  State<AuditPage> createState() => _AuditPageState();
}

const _tables = {
  'leads': 'Leads',
  'clients': 'Clients',
  'contacts': 'Contacts',
  'consents': 'Consents',
  'quotes': 'Quotes',
  'quote_line_items': 'Quote lines',
  'invoices': 'Invoices',
  'payments': 'Payments',
  'packages': 'Price list',
  'settings': 'Settings',
  'team_members': 'Team',
};

class _AuditPageState extends State<AuditPage> {
  String? _table;

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        const PageHeader(
          'Audit log',
          subtitle:
              'Who added, changed, deleted or exported records, and when. Written by the database; nobody can edit it.',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Everything'),
              selected: _table == null,
              onSelected: (_) => setState(() => _table = null),
            ),
            for (final e in _tables.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _table == e.key,
                onSelected: (_) => setState(() => _table = e.key),
              ),
          ],
        ),
        Card(
          semanticContainer: false,

          child: Loader<List<AuditEntry>>(
            key: ValueKey(_table),
            load: () => repo.auditLog(table: _table),
            builder: (context, list, _) => list.isEmpty
                ? const EmptyState('Nothing recorded yet.')
                : Column(
                    children: [
                      for (final a in list)
                        ListTile(
                          dense: true,
                          leading: Icon(switch (a.action) {
                            'insert' => Icons.add_circle_outline,
                            'delete' => Icons.delete_outline,
                            'export' => Icons.download_outlined,
                            _ => Icons.edit_outlined,
                          }),
                          title: Text(
                            '${_tables[a.tableName] ?? a.tableName}: ${switch (a.action) {
                              'insert' => 'added',
                              'delete' => 'deleted',
                              'export' => 'exported',
                              _ => 'changed ${a.changedFields?.map((f) => f.replaceAll('_', ' ')).join(', ') ?? ''}',
                            }}',
                          ),
                          subtitle: Text('${dateTime(a.changedAt)} · ${a.byName ?? 'Website or system'}'),
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
