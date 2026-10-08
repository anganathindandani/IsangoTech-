import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';
import 'dialogs.dart';

class ClientPage extends StatefulWidget {
  const ClientPage({super.key, required this.id});
  final String id;

  @override
  State<ClientPage> createState() => _ClientPageState();
}

class _ClientData {
  _ClientData(this.client, this.contacts, this.stages, this.quotes, this.invoices, this.activities, this.assessments);
  final Client client;
  final List<Contact> contacts;
  final List<StageChange> stages;
  final List<Quote> quotes;
  final List<Invoice> invoices;
  final List<Activity> activities;
  final List<Assessment> assessments;
}

class _ClientPageState extends State<ClientPage> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  Future<_ClientData> _load() async {
    final id = widget.id;
    final r = await Future.wait([
      repo.client(id),
      repo.contacts(id),
      repo.stageChanges(id),
      repo.quotes(clientId: id),
      repo.invoices(clientId: id),
      repo.activities(clientId: id),
      repo.assessments(clientId: id),
    ]);
    return _ClientData(
      r[0] as Client,
      r[1] as List<Contact>,
      r[2] as List<StageChange>,
      r[3] as List<Quote>,
      r[4] as List<Invoice>,
      r[5] as List<Activity>,
      r[6] as List<Assessment>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Loader<_ClientData>(
      key: _key,
      load: _load,
      builder: (context, d, _) {
        final c = d.client;
        final reviewDue = c.nextStageReviewDate != null && !c.nextStageReviewDate!.isAfter(DateTime.now());
        return PageBody(
          children: [
            PageHeader(
              c.businessName,
              subtitle: [clientStatuses[c.status], c.industryName].whereType<String>().join(' · '),
              actions: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                  onPressed: () async {
                    if (await showDialog<bool>(
                          context: context,
                          builder: (_) => ClientDialog(client: c),
                        ) ==
                        true) {
                      _reload();
                    }
                  },
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.request_quote_outlined),
                  label: const Text('New quote'),
                  onPressed: () async {
                    String? id;
                    final ok = await run(context, () async => id = await repo.createQuote(clientId: c.id));
                    if (ok && context.mounted) context.go('/quotes/$id');
                  },
                ),
              ],
            ),
            Columns(
              left: [
                Section(
                  title: 'Growth path',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Field('Current stage', c.growthStage == null ? 'Not set' : stageLabel(c.growthStage)),
                      Field(
                        'Next-stage review',
                        c.nextStageReviewDate == null
                            ? 'Not set'
                            : '${date(c.nextStageReviewDate)}${reviewDue ? ' · due now' : ''}',
                      ),
                      if (d.stages.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        for (final s in d.stages.reversed)
                          Text(
                            '${date(s.changedAt)}: ${s.fromStage == null ? 'Started at' : 'Moved from ${growthStages[s.fromStage]} to'} ${growthStages[s.toStage] ?? 'not set'}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                      ],
                    ],
                  ),
                ),
                Section(
                  title: 'Quotes',
                  child: d.quotes.isEmpty
                      ? const EmptyState('No quotes yet.')
                      : Column(
                          children: [
                            for (final q in d.quotes)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(q.number),
                                subtitle: Text(
                                  '${money(q.total)}${q.monthlyTotal > 0 ? ' + ${money(q.monthlyTotal)} / month' : ''} · ${date(q.createdAt)}',
                                ),
                                trailing: StatusChip(
                                  quoteStatuses[q.status] ?? q.status,
                                  color: StatusChip.colorFor(q.status),
                                ),
                                onTap: () => context.go('/quotes/${q.id}'),
                              ),
                          ],
                        ),
                ),
                Section(
                  title: 'Invoices',
                  child: d.invoices.isEmpty
                      ? const EmptyState('No invoices yet.')
                      : Column(
                          children: [
                            for (final i in d.invoices)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${i.displayNumber} · ${money(i.amount)}'),
                                subtitle: Text(i.dueDate == null ? invoiceTypes[i.type]! : 'Due ${date(i.dueDate)}'),
                                trailing: StatusChip(
                                  i.isOverdue ? 'Overdue' : paymentStatuses[i.paymentStatus] ?? i.paymentStatus,
                                  color: StatusChip.colorFor(i.isOverdue ? 'overdue' : i.paymentStatus),
                                ),
                                onTap: () => context.go('/invoices/${i.id}'),
                              ),
                          ],
                        ),
                ),
                Section(
                  title: 'Activity',
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Log activity'),
                    onPressed: () async {
                      if (await showDialog<bool>(
                            context: context,
                            builder: (_) => ActivityDialog(clientId: c.id),
                          ) ==
                          true) {
                        _reload();
                      }
                    },
                  ),
                  child: d.activities.isEmpty
                      ? const EmptyState('No activity logged for this client.')
                      : Column(
                          children: [
                            for (final a in d.activities)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(a.summary),
                                subtitle: Text('${activityTypes[a.type]} · ${dateTime(a.occurredAt)}'),
                              ),
                          ],
                        ),
                ),
              ],
              right: [
                Section(
                  title: 'Contacts',
                  trailing: IconButton(
                    tooltip: 'Add contact',
                    icon: const Icon(Icons.person_add_alt),
                    onPressed: () async {
                      if (await showDialog<bool>(
                            context: context,
                            builder: (_) => ContactDialog(clientId: c.id),
                          ) ==
                          true) {
                        _reload();
                      }
                    },
                  ),
                  child: d.contacts.isEmpty
                      ? const EmptyState('No contacts.')
                      : Column(
                          children: [
                            for (final k in d.contacts)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('${k.fullName}${k.isPrimary ? ' (main)' : ''}'),
                                subtitle: Text([k.role, k.phone, k.email].whereType<String>().join(' · ')),
                                onTap: () async {
                                  if (await showDialog<bool>(
                                        context: context,
                                        builder: (_) => ContactDialog(clientId: c.id, contact: k),
                                      ) ==
                                      true) {
                                    _reload();
                                  }
                                },
                              ),
                          ],
                        ),
                ),
                Section(
                  title: 'Business details',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Field('Address', c.address),
                      Field('Systems they use', c.systemsUsed),
                      Field('Client since', c.startDate == null ? null : date(c.startDate)),
                      Field('Notes', c.notes),
                    ],
                  ),
                ),
                Section(
                  title: 'Assessments',
                  trailing: TextButton.icon(
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Book'),
                    onPressed: () async {
                      if (await showDialog<bool>(
                            context: context,
                            builder: (_) => BookAssessmentDialog(clientId: c.id),
                          ) ==
                          true) {
                        _reload();
                      }
                    },
                  ),
                  child: d.assessments.isEmpty
                      ? const EmptyState('No assessments.')
                      : Column(children: [for (final a in d.assessments) AssessmentTile(a, onChanged: _reload)]),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
