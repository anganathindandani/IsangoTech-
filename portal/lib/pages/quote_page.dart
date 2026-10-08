import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../pdf/documents.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'dialogs.dart';

class QuotePage extends StatefulWidget {
  const QuotePage({super.key, required this.id});
  final String id;

  @override
  State<QuotePage> createState() => _QuotePageState();
}

class _QuoteData {
  _QuoteData(this.quote, this.settings, this.contacts);
  final Quote quote;
  final Map<String, dynamic> settings;
  final List<Contact> contacts;
}

class _QuotePageState extends State<QuotePage> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  Future<_QuoteData> _load() async {
    final quote = await repo.quote(widget.id);
    final r = await Future.wait([repo.settingsMap(), repo.contacts(quote.clientId)]);
    return _QuoteData(quote, r[0] as Map<String, dynamic>, r[1] as List<Contact>);
  }

  Future<void> _status(Quote q, String status, {String? done}) async {
    await run(context, () => repo.setQuoteStatus(q.id, status), done: done);
    _reload();
  }

  Future<void> _pdf(_QuoteData d) async {
    final ok = await run(context, () async {
      final bytes = await quotePdf(
        d.quote,
        d.contacts.where((c) => c.isPrimary).firstOrNull,
        vatRegistered: d.settings['vat_registered'] == true,
      );
      await repo.logExport('quotes', [d.quote.id]);
      await Printing.sharePdf(bytes: bytes, filename: '${d.quote.number}.pdf');
    });
    if (!ok) return;
  }

  @override
  Widget build(BuildContext context) {
    return Loader<_QuoteData>(
      key: _key,
      load: _load,
      builder: (context, d, _) {
        final q = d.quote;
        final threshold = (d.settings['quote_approval_amount'] as num?) ?? 0;
        final needsApproval = q.firstYearValue > threshold;
        final actions = <Widget>[
          OutlinedButton.icon(
            onPressed: q.lines.isEmpty ? null : () => _pdf(d),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Download PDF'),
          ),
          if (q.status == 'draft' && needsApproval)
            FilledButton(
              onPressed: q.lines.isEmpty ? null : () => _status(q, 'pending_approval', done: 'Waiting for approval'),
              child: const Text('Ask for approval'),
            ),
          if (q.status == 'pending_approval' && q.approvedAt == null)
            FilledButton(
              onPressed: () async {
                await run(context, () => repo.approveQuote(q.id), done: 'Quote approved');
                _reload();
              },
              child: const Text('Approve'),
            ),
          if (q.editable && (!needsApproval || q.approvedAt != null))
            FilledButton(
              onPressed: q.lines.isEmpty
                  ? null
                  : () async {
                      if (await confirm(
                        context,
                        'Mark as sent?',
                        'Send the PDF to the client by email or WhatsApp, then mark it as sent here. A sent quote can no longer be changed.',
                        action: 'Mark as sent',
                      )) {
                        await _status(q, 'sent', done: 'Quote marked as sent');
                      }
                    },
              child: const Text('Mark as sent'),
            ),
          if (q.status == 'sent') ...[
            FilledButton(
              onPressed: () => _status(q, 'accepted', done: 'Quote accepted. The client is now active.'),
              child: const Text('Accepted'),
            ),
            OutlinedButton(
              onPressed: () => _status(q, 'declined', done: 'Lead sent back to the pipeline for follow-up'),
              child: const Text('Declined'),
            ),
            TextButton(onPressed: () => _status(q, 'expired'), child: const Text('Expired')),
          ],
          if (q.status == 'accepted' && q.total > 0)
            FilledButton.icon(
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Create setup invoice'),
              onPressed: () async {
                String? id;
                final ok = await run(context, () async => id = await repo.invoiceFromQuote(q));
                if (ok && context.mounted) context.go('/invoices/$id');
              },
            ),
        ];

        return PageBody(
          children: [
            PageHeader(q.number, subtitle: q.clientName, actions: actions),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(quoteStatuses[q.status] ?? q.status, color: StatusChip.colorFor(q.status)),
                if (q.approvedAt != null) StatusChip('Approved ${date(q.approvedAt)}', color: Brand.turquoiseText),
                Text('Valid until ${date(q.validUntil)}'),
                TextButton(onPressed: () => context.go('/clients/${q.clientId}'), child: const Text('Open client')),
              ],
            ),
            if (q.editable && needsApproval && q.approvedAt == null)
              Card(
                semanticContainer: false,

                color: Brand.ochre.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'This quote is worth ${money(q.firstYearValue)} in its first year, above the ${money(threshold)} approval amount, so an admin must approve it before it is sent.',
                  ),
                ),
              ),
            Section(
              title: 'Lines',
              trailing: q.editable
                  ? TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add line'),
                      onPressed: () async {
                        if (await showDialog<bool>(
                              context: context,
                              builder: (_) => QuoteLineDialog(quoteId: q.id, nextSortOrder: q.lines.length),
                            ) ==
                            true) {
                          _reload();
                        }
                      },
                    )
                  : null,
              child: Column(
                children: [
                  if (q.lines.isEmpty) const EmptyState('Add packages from the price list, or custom lines.'),
                  for (final l in q.lines)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.description),
                      subtitle: Text(
                        '${l.quantity} × ${money(l.unitPrice)}${l.billing == 'monthly' ? ' per month' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(money(l.lineTotal), style: const TextStyle(fontWeight: FontWeight.w500)),
                          if (q.editable) ...[
                            IconButton(
                              tooltip: 'Edit line',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                if (await showDialog<bool>(
                                      context: context,
                                      builder: (_) => QuoteLineDialog(quoteId: q.id, line: l),
                                    ) ==
                                    true) {
                                  _reload();
                                }
                              },
                            ),
                            IconButton(
                              tooltip: 'Remove line',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                await run(context, () => repo.deleteQuoteLine(l.id));
                                _reload();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  const Divider(),
                  _TotalRow('Once-off total', money(q.total)),
                  if (q.monthlyTotal > 0) _TotalRow('Monthly', '${money(q.monthlyTotal)} / month'),
                  _TotalRow('First-year value', money(q.firstYearValue), muted: true),
                ],
              ),
            ),
            Section(
              title: 'Notes on the quote',
              trailing: q.editable
                  ? IconButton(
                      tooltip: 'Edit notes',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () async {
                        final text = await promptText(
                          context,
                          'Notes on the quote',
                          label: 'Shown on the PDF',
                          initial: q.notes ?? '',
                        );
                        if (text == null || !context.mounted) return;
                        await run(context, () => repo.updateQuote(q.id, {'notes': text.isEmpty ? null : text}));
                        _reload();
                      },
                    )
                  : null,
              child: Text(q.notes ?? 'None.'),
            ),
          ],
        );
      },
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value, {this.muted = false});
  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
      color: muted ? Colors.black54 : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
