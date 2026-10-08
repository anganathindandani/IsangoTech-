import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';
import 'dialogs.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  String? _status;
  String _search = '';
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        PageHeader(
          'Clients',
          subtitle: 'Prospects and clients, with where each one is on the growth path.',
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New client'),
              onPressed: () async {
                String? id;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => ClientDialog(onCreated: (v) => id = v),
                );
                if (ok == true && id != null && context.mounted) context.go('/clients/$id');
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
              selected: _status == null,
              onSelected: (_) => setState(() => _status = null),
            ),
            for (final e in clientStatuses.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: _status == e.key,
                onSelected: (_) => setState(() => _status = e.key),
              ),
          ],
        ),
        TextField(
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search business name'),
          onSubmitted: (v) => setState(() => _search = v),
        ),
        Card(
          semanticContainer: false,

          child: Loader<List<Client>>(
            key: ValueKey('$_key$_status$_search'),
            load: () => repo.clients(status: _status, search: _search),
            builder: (context, clients, _) => clients.isEmpty
                ? const EmptyState('No clients yet. A client is created when you send a lead their first quote.')
                : Column(
                    children: [
                      for (final c in clients)
                        ListTile(
                          title: Text(c.businessName),
                          subtitle: Text(
                            [
                              c.industryName,
                              c.growthStage == null ? null : stageLabel(c.growthStage),
                            ].whereType<String>().join(' · '),
                          ),
                          trailing: StatusChip(
                            clientStatuses[c.status] ?? c.status,
                            color: StatusChip.colorFor(c.status),
                          ),
                          onTap: () async {
                            await context.push('/clients/${c.id}');
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
