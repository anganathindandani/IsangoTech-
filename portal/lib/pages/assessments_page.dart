import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';
import 'dialogs.dart';

class AssessmentsPage extends StatefulWidget {
  const AssessmentsPage({super.key});

  @override
  State<AssessmentsPage> createState() => _AssessmentsPageState();
}

class _AssessmentsPageState extends State<AssessmentsPage> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        PageHeader(
          'Assessments',
          subtitle: 'AI Readiness Assessments and the booking slots website visitors can pick from.',
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add slot'),
              onPressed: () async {
                if (await showDialog<bool>(context: context, builder: (_) => const SlotDialog()) == true) _reload();
              },
            ),
          ],
        ),
        Columns(
          left: [
            Section(
              title: 'Upcoming assessments',
              child: Loader<List<Assessment>>(
                key: ValueKey('a$_key'),
                load: () => repo.assessments(upcomingOnly: true),
                builder: (context, list, _) => list.isEmpty
                    ? const EmptyState('Nothing booked.')
                    : Column(children: [for (final a in list) AssessmentTile(a, onChanged: _reload, showWho: true)]),
              ),
            ),
            Section(
              title: 'Past assessments',
              child: Loader<List<Assessment>>(
                key: ValueKey('p$_key'),
                load: () async => (await repo.assessments())
                    .where((a) => a.status != 'booked' || (a.scheduledAt?.isBefore(DateTime.now()) ?? false))
                    .toList(),
                builder: (context, list, _) => list.isEmpty
                    ? const EmptyState('No past assessments.')
                    : Column(
                        children: [for (final a in list.take(30)) AssessmentTile(a, onChanged: _reload, showWho: true)],
                      ),
              ),
            ),
          ],
          right: [
            Section(
              title: 'Booking slots',
              child: Loader<List<BookingSlot>>(
                key: ValueKey('s$_key'),
                load: () => repo.slots(),
                builder: (context, slots, _) => slots.isEmpty
                    ? const EmptyState('No upcoming slots. Add some so website visitors can book.')
                    : Column(
                        children: [
                          for (final s in slots)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(dateTime(s.startsAt)),
                              subtitle: Text(s.mode == 'online' ? 'Online' : s.location ?? 'In person'),
                              trailing: s.status == 'open'
                                  ? TextButton(
                                      onPressed: () async {
                                        if (!await confirm(
                                          context,
                                          'Cancel this slot?',
                                          'It will no longer be offered on the website.',
                                          action: 'Cancel slot',
                                        )) {
                                          return;
                                        }
                                        if (!context.mounted) return;
                                        await run(context, () => repo.cancelSlot(s.id));
                                        _reload();
                                      },
                                      child: const Text('Cancel'),
                                    )
                                  : StatusChip(
                                      s.status == 'booked' ? 'Booked' : 'Cancelled',
                                      color: StatusChip.colorFor(s.status),
                                    ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
