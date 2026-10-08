import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';

class QuotesPage extends StatefulWidget {
  const QuotesPage({super.key});

  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  String? _status;
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        const PageHeader('Quotes', subtitle: 'Start a quote from a lead or a client.'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _status == null,
              onSelected: (_) => setState(() => _status = null),
            ),
            for (final e in quoteStatuses.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _status == e.key,
                onSelected: (_) => setState(() => _status = e.key),
              ),
          ],
        ),
        Card(
          semanticContainer: false,

          child: Loader<List<Quote>>(
            key: ValueKey('$_key$_status'),
            load: () => repo.quotes(status: _status),
            builder: (context, list, _) => list.isEmpty
                ? const EmptyState('No quotes here.')
                : Column(
                    children: [
                      for (final q in list)
                        ListTile(
                          title: Text('${q.number} · ${q.clientName}'),
                          subtitle: Text(
                            '${money(q.total)}${q.monthlyTotal > 0 ? ' + ${money(q.monthlyTotal)} / month' : ''} · ${date(q.createdAt)}',
                          ),
                          trailing: StatusChip(
                            quoteStatuses[q.status] ?? q.status,
                            color: StatusChip.colorFor(q.status),
                          ),
                          onTap: () async {
                            await context.push('/quotes/${q.id}');
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
