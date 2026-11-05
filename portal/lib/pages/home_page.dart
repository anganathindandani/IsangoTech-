import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';
import 'dialogs.dart';
import 'leads_page.dart';

class _Today {
  _Today(this.followUps, this.newLeads, this.pendingQuotes, this.overdue, this.assessments);
  final List<Lead> followUps;
  final List<Lead> newLeads;
  final List<Quote> pendingQuotes;
  final List<Invoice> overdue;
  final List<Assessment> assessments;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  Future<_Today> _load() async {
    final r = await Future.wait([
      repo.followUpsDue(),
      repo.leads(pipelineStage: 'new'),
      repo.quotes(status: 'pending_approval'),
      repo.invoices(overdueOnly: true),
      repo.assessments(upcomingOnly: true),
    ]);
    return _Today(
      r[0] as List<Lead>,
      r[1] as List<Lead>,
      r[2] as List<Quote>,
      r[3] as List<Invoice>,
      (r[4] as List<Assessment>)
          .where((a) => a.scheduledAt!.isBefore(DateTime.now().add(const Duration(days: 7))))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        PageHeader(
          'Today',
          subtitle: date(DateTime.now()),
          actions: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Quick add lead'),
              onPressed: () async {
                final id = await showDialog<String>(context: context, builder: (_) => const QuickAddLeadDialog());
                if (id != null && context.mounted) context.go('/leads/$id');
              },
            ),
          ],
        ),
        Loader<_Today>(
          key: _key,
          load: _load,
          placeholder: const _TodaySkeleton(),
          builder: (context, t, _) => Columns(
            left: [
              Section(
                title: 'Follow-ups due (${t.followUps.length})',
                child: t.followUps.isEmpty
                    ? const EmptyState('No follow-ups due today.', icon: Icons.event_outlined)
                    : Column(
                        children: [
                          for (final l in t.followUps) LeadTile(l, onReturn: _reload, contentPadding: EdgeInsets.zero),
                        ],
                      ),
              ),
              Section(
                title: 'New leads (${t.newLeads.length})',
                child: t.newLeads.isEmpty
                    ? const EmptyState('No new leads waiting.', icon: Icons.person_search_outlined)
                    : Column(
                        children: [
                          for (final l in t.newLeads.take(10))
                            LeadTile(l, onReturn: _reload, contentPadding: EdgeInsets.zero),
                        ],
                      ),
              ),
            ],
            right: [
              Section(
                title: 'Assessments this week',
                child: t.assessments.isEmpty
                    ? const EmptyState('No assessments booked this week.', icon: Icons.event_available_outlined)
                    : Column(
                        children: [for (final a in t.assessments) AssessmentTile(a, onChanged: _reload, showWho: true)],
                      ),
              ),
              Section(
                title: 'Quotes waiting for approval',
                child: t.pendingQuotes.isEmpty
                    ? const EmptyState('No quotes waiting for approval.', icon: Icons.request_quote_outlined)
                    : Column(
                        children: [
                          for (final q in t.pendingQuotes)
                            DataTile(
                              contentPadding: EdgeInsets.zero,
                              title: '${q.number} · ${q.clientName}',
                              subtitle: 'First year ${money(q.firstYearValue)}',
                              onTap: () => context.go('/quotes/${q.id}'),
                            ),
                        ],
                      ),
              ),
              Section(
                title: 'Overdue invoices',
                child: t.overdue.isEmpty
                    ? const EmptyState('No overdue invoices.', icon: Icons.receipt_long_outlined)
                    : Column(
                        children: [
                          for (final i in t.overdue)
                            DataTile(
                              contentPadding: EdgeInsets.zero,
                              title: '${i.displayNumber} · ${i.clientName}',
                              subtitle: '${money(i.balance)} owed · due ${date(i.dueDate)}',
                              onTap: () => context.go('/invoices/${i.id}'),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TodaySkeleton extends StatelessWidget {
  const _TodaySkeleton();

  @override
  Widget build(BuildContext context) {
    const list = SkeletonList(rows: 3, trailing: true, padding: EdgeInsets.zero);
    const short = SkeletonList(rows: 2, padding: EdgeInsets.zero);
    return const Columns(
      left: [
        Section(title: 'Follow-ups due', child: list),
        Section(title: 'New leads', child: list),
      ],
      right: [
        Section(title: 'Assessments this week', child: list),
        Section(title: 'Quotes waiting for approval', child: short),
        Section(title: 'Overdue invoices', child: short),
      ],
    );
  }
}
