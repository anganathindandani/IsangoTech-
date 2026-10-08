import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';
import 'dialogs.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  /// 'overdue' is a pseudo-filter on is_overdue.
  String? _filter;
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    const filters = {
      'overdue': 'Overdue',
      'unpaid': 'Unpaid',
      'part_paid': 'Part paid',
      'draft': 'Draft',
      'paid': 'Paid',
      'void': 'Void',
    };
    return PageBody(
      children: [
        PageHeader(
          'Invoices',
          subtitle: 'Setup, monthly and custom invoices, and the payments against them.',
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New invoice'),
              onPressed: () async {
                String? id;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => NewInvoiceDialog(onCreated: (v) => id = v),
                );
                if (ok == true && id != null && context.mounted) context.go('/invoices/$id');
              },
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final e in filters.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _filter == e.key,
                onSelected: (_) => setState(() => _filter = e.key),
              ),
          ],
        ),
        Card(
          semanticContainer: false,

          child: Loader<List<Invoice>>(
            key: ValueKey('$_key$_filter'),
            load: () =>
                repo.invoices(paymentStatus: _filter == 'overdue' ? null : _filter, overdueOnly: _filter == 'overdue'),
            builder: (context, list, _) => list.isEmpty
                ? const EmptyState('No invoices here.')
                : Column(
                    children: [
                      for (final i in list)
                        ListTile(
                          title: Text('${i.displayNumber} · ${i.clientName}'),
                          subtitle: Text(
                            [
                              money(i.amount),
                              if (i.paid > 0 && i.balance > 0) '${money(i.balance)} still owed',
                              if (i.dueDate != null) 'due ${date(i.dueDate)}',
                            ].join(' · '),
                          ),
                          trailing: StatusChip(
                            i.isOverdue ? 'Overdue' : paymentStatuses[i.paymentStatus] ?? i.paymentStatus,
                            color: StatusChip.colorFor(i.isOverdue ? 'overdue' : i.paymentStatus),
                          ),
                          onTap: () async {
                            await context.push('/invoices/${i.id}');
                            setState(() => _key = UniqueKey());
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
