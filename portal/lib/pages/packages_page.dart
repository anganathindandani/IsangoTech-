import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';
import 'dialogs.dart';

class PackagesPage extends StatefulWidget {
  const PackagesPage({super.key});

  @override
  State<PackagesPage> createState() => _PackagesPageState();
}

class _PackagesPageState extends State<PackagesPage> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        PageHeader(
          'Price list',
          subtitle: 'Packages you can add to quotes. Changing a price here doesn\'t change quotes already made.',
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('New package'),
              onPressed: () async {
                if (await showDialog<bool>(context: context, builder: (_) => const PackageDialog()) == true) _reload();
              },
            ),
          ],
        ),
        Card(
          semanticContainer: false,

          child: Loader<List<Package>>(
            key: _key,
            load: () => repo.packages(),
            builder: (context, list, _) => list.isEmpty
                ? const EmptyState(
                    'No packages yet. Add your Starter website, Core Starter, Core Business, AI Readiness Assessment and care plan.',
                  )
                : Column(
                    children: [
                      for (final p in list)
                        ListTile(
                          title: Text(p.name, style: TextStyle(color: p.active ? null : Colors.black45)),
                          subtitle: Text(
                            [
                              p.growthStage == null ? 'Every stage' : stageLabel(p.growthStage),
                              if (!p.active) 'Not available on new quotes',
                            ].join(' · '),
                          ),
                          trailing: Text('${money(p.price)}${p.billing == 'monthly' ? ' / month' : ''}'),
                          onTap: () async {
                            if (await showDialog<bool>(
                                  context: context,
                                  builder: (_) => PackageDialog(package: p),
                                ) ==
                                true) {
                              _reload();
                            }
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
