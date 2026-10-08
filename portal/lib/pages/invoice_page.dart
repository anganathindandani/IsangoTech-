import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../pdf/documents.dart';
import '../widgets/ui.dart';
import 'dialogs.dart';

class InvoicePage extends StatefulWidget {
  const InvoicePage({super.key, required this.id});
  final String id;

  @override
  State<InvoicePage> createState() => _InvoicePageState();
}

class _InvoicePageState extends State<InvoicePage> {
  Key _key = UniqueKey();
  void _reload() => setState(() => _key = UniqueKey());

  Future<void> _pdf(Invoice i) async {
    await run(context, () async {
      final settings = await repo.settingsMap();
      final contacts = await repo.contacts(i.clientId);
      final bytes = await invoicePdf(
        i,
        contacts.where((c) => c.isPrimary).firstOrNull,
        vatRegistered: settings['vat_registered'] == true,
        paymentDetails: settings['invoice_payment_details'] as String?,
      );
      await repo.logExport('invoices', [i.id]);
      await Printing.sharePdf(bytes: bytes, filename: '${i.displayNumber}.pdf');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Loader<Invoice>(
      key: _key,
      load: () => repo.invoice(widget.id),
      builder: (context, i, _) {
        final canPay = i.status == 'sent' && i.balance > 0;
        return PageBody(
          maxWidth: 900,
          children: [
            PageHeader(
              i.displayNumber,
              subtitle: i.clientName,
              actions: [
                OutlinedButton.icon(
                  onPressed: () => _pdf(i),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Download PDF'),
                ),
                if (i.status == 'draft') ...[
                  FilledButton(
                    onPressed: () async {
                      if (!await confirm(
                        context,
                        'Mark as sent?',
                        'This gives the invoice its number and due date. A sent invoice can no longer be changed; void it instead.',
                        action: 'Mark as sent',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      await run(
                        context,
                        () => repo.updateInvoice(i.id, {'status': 'sent'}),
                        done: 'Invoice numbered and marked as sent',
                      );
                      _reload();
                    },
                    child: const Text('Mark as sent'),
                  ),
                  TextButton(
                    onPressed: () async {
                      if (!await confirm(
                        context,
                        'Delete draft?',
                        'The draft is removed. No invoice number is used.',
                        action: 'Delete',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      if (await run(context, () => repo.deleteDraftInvoice(i.id)) && context.mounted) {
                        context.go('/invoices');
                      }
                    },
                    child: const Text('Delete draft'),
                  ),
                ],
                if (canPay)
                  FilledButton.icon(
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Record payment'),
                    onPressed: () async {
                      if (await showDialog<bool>(
                            context: context,
                            builder: (_) => PaymentDialog(invoice: i),
                          ) ==
                          true) {
                        _reload();
                      }
                    },
                  ),
                if (i.status == 'sent' && i.payments.isEmpty)
                  TextButton(
                    onPressed: () async {
                      if (!await confirm(
                        context,
                        'Void this invoice?',
                        'It stays on record as void and can no longer be paid.',
                        action: 'Void',
                      )) {
                        return;
                      }
                      if (!context.mounted) return;
                      await run(context, () => repo.updateInvoice(i.id, {'status': 'void'}));
                      _reload();
                    },
                    child: const Text('Void'),
                  ),
              ],
            ),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusChip(
                  i.isOverdue ? 'Overdue' : paymentStatuses[i.paymentStatus] ?? i.paymentStatus,
                  color: StatusChip.colorFor(i.isOverdue ? 'overdue' : i.paymentStatus),
                ),
                TextButton(onPressed: () => context.go('/clients/${i.clientId}'), child: const Text('Open client')),
                if (i.quoteId != null)
                  TextButton(onPressed: () => context.go('/quotes/${i.quoteId}'), child: const Text('Open quote')),
              ],
            ),
            Columns(
              left: [
                Section(
                  title: 'Payments',
                  child: Column(
                    children: [
                      if (i.payments.isEmpty) const EmptyState('No payments recorded.'),
                      for (final p in i.payments)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(money(p.amount)),
                          subtitle: Text(
                            [
                              date(p.paidOn),
                              paymentMethods[p.method] ?? p.method,
                              p.reference,
                            ].whereType<String>().join(' · '),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              right: [
                Section(
                  title: 'Invoice',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Field('Type', invoiceTypes[i.type]),
                      Field('Description', i.description),
                      Field('Amount', money(i.amount)),
                      Field('Paid', money(i.paid)),
                      Field('Still owed', money(i.balance)),
                      Field('Issued', i.issueDate == null ? 'Not sent yet' : date(i.issueDate)),
                      Field('Due', i.dueDate == null ? 'Set when sent' : date(i.dueDate)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
