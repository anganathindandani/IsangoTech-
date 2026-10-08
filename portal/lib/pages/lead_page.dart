import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';
import 'dialogs.dart';

class LeadPage extends StatefulWidget {
  const LeadPage({super.key, required this.id});
  final String id;

  @override
  State<LeadPage> createState() => _LeadPageState();
}

class _LeadData {
  _LeadData(this.lead, this.activities, this.consents, this.assessments);
  final Lead lead;
  final List<Activity> activities;
  final List<Consent> consents;
  final List<Assessment> assessments;
}

class _LeadPageState extends State<LeadPage> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  Future<_LeadData> _load() async {
    final r = await Future.wait([
      repo.lead(widget.id),
      repo.activities(leadId: widget.id),
      repo.consents(leadId: widget.id),
      repo.assessments(leadId: widget.id),
    ]);
    return _LeadData(r[0] as Lead, r[1] as List<Activity>, r[2] as List<Consent>, r[3] as List<Assessment>);
  }

  Future<void> _setStage(Lead lead, String stage) async {
    String? reason;
    if (stage == 'lost') {
      reason = await promptText(context, 'Why was it lost?', label: 'Reason (optional)');
      if (reason == null) return;
    }
    if (!mounted) return;
    await run(
      context,
      () => repo.updateLead(lead.id, {'pipeline_stage': stage, if (stage == 'lost') 'lost_reason': reason}),
    );
    _reload();
  }

  Future<void> _createQuote(Lead lead) async {
    String? quoteId;
    final ok = await run(context, () async => quoteId = await repo.createQuoteForLead(lead.id));
    if (ok && mounted) context.go('/quotes/$quoteId');
  }

  @override
  Widget build(BuildContext context) {
    return Loader<_LeadData>(
      key: _key,
      load: _load,
      builder: (context, d, reload) {
        final lead = d.lead;
        return PageBody(
          children: [
            PageHeader(
              lead.fullName,
              subtitle: [lead.businessName, lead.industryName].whereType<String>().join(' · '),
              actions: [
                if (lead.clientId != null)
                  OutlinedButton.icon(
                    onPressed: () => context.go('/clients/${lead.clientId}'),
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Open client'),
                  ),
                FilledButton.icon(
                  onPressed: () => _createQuote(lead),
                  icon: const Icon(Icons.request_quote_outlined),
                  label: const Text('Create quote'),
                ),
              ],
            ),
            Columns(
              left: [
                Section(
                  title: 'Pipeline',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final e in pipelineStages.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: lead.pipelineStage == e.key,
                          onSelected: (_) => _setStage(lead, e.key),
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
                            builder: (_) => ActivityDialog(leadId: lead.id),
                          ) ==
                          true) {
                        _reload();
                      }
                    },
                  ),
                  child: d.activities.isEmpty
                      ? const EmptyState('No calls, messages or notes yet.')
                      : Column(
                          children: [
                            for (final a in d.activities)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(_activityIcon(a.type)),
                                title: Text(a.summary),
                                subtitle: Text(
                                  '${activityTypes[a.type]} · ${dateTime(a.occurredAt)}${a.byName == null ? '' : ' · ${a.byName}'}',
                                ),
                              ),
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
                            builder: (_) => BookAssessmentDialog(leadId: lead.id),
                          ) ==
                          true) {
                        _reload();
                      }
                    },
                  ),
                  child: d.assessments.isEmpty
                      ? const EmptyState('No assessment booked. Most stage 1–2 leads go straight to a quote.')
                      : Column(children: [for (final a in d.assessments) AssessmentTile(a, onChanged: _reload)]),
                ),
              ],
              right: [
                Section(
                  title: 'Details',
                  trailing: IconButton(
                    tooltip: 'Edit details',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      if (await showDialog<bool>(
                            context: context,
                            builder: (_) => EditLeadDialog(lead: lead),
                          ) ==
                          true) {
                        _reload();
                      }
                    },
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Field('Phone', lead.phone),
                      Field('Email', lead.email),
                      Field('Source', leadSources[lead.source]),
                      Field('Stage needed', stageLabel(lead.stageNeeded)),
                      Field('Biggest headache', lead.biggestPain),
                      if (lead.pipelineStage == 'lost') Field('Lost because', lead.lostReason),
                      Field('Received', dateTime(lead.createdAt)),
                    ],
                  ),
                ),
                Section(
                  title: 'Next follow-up',
                  child: Row(
                    children: [
                      Expanded(child: Text(lead.nextFollowUp == null ? 'None set' : date(lead.nextFollowUp))),
                      TextButton(
                        onPressed: () async {
                          final picked = await pickDate(context, initial: lead.nextFollowUp);
                          if (picked == null || !context.mounted) return;
                          await run(context, () => repo.updateLead(lead.id, {'next_follow_up': isoDate(picked)}));
                          _reload();
                        },
                        child: const Text('Set date'),
                      ),
                      if (lead.nextFollowUp != null)
                        TextButton(
                          onPressed: () async {
                            await run(context, () => repo.updateLead(lead.id, {'next_follow_up': null}));
                            _reload();
                          },
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
                ConsentsSection(consents: d.consents, onChanged: _reload),
              ],
            ),
          ],
        );
      },
    );
  }
}

IconData _activityIcon(String type) => switch (type) {
  'call' => Icons.call_outlined,
  'message' => Icons.chat_outlined,
  'meeting' => Icons.groups_outlined,
  _ => Icons.sticky_note_2_outlined,
};

class ConsentsSection extends StatelessWidget {
  const ConsentsSection({super.key, required this.consents, required this.onChanged});
  final List<Consent> consents;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Section(
      title: 'Consent',
      child: consents.isEmpty
          ? const EmptyState('No consent recorded.')
          : Column(
              children: [
                for (final c in consents)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(consentPurposes[c.purpose] ?? c.purpose),
                    subtitle: Text(
                      c.withdrawnAt == null
                          ? 'Given ${date(c.givenAt)} · policy v${c.policyVersion} · ${consentSources[c.source] ?? c.source}'
                          : 'Withdrawn ${date(c.withdrawnAt)}',
                    ),
                    trailing: c.withdrawnAt == null
                        ? TextButton(
                            onPressed: () async {
                              if (!await confirm(
                                context,
                                'Withdraw consent?',
                                'Record that this person withdrew consent for ${consentPurposes[c.purpose]?.toLowerCase()}.',
                                action: 'Withdraw',
                              )) {
                                return;
                              }
                              if (!context.mounted) return;
                              await run(context, () => repo.withdrawConsent(c.id));
                              onChanged();
                            },
                            child: const Text('Withdraw'),
                          )
                        : null,
                  ),
              ],
            ),
    );
  }
}
