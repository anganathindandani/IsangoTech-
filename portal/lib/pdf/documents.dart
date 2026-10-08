import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/models.dart';
import '../format.dart';

const _indigo = PdfColor.fromInt(0xFF1B2A4A);
const _ochre = PdfColor.fromInt(0xFFE07A1F);
const _turquoise = PdfColor.fromInt(0xFF1D7A74);
const _sand = PdfColor.fromInt(0xFFF5EBDD);
const _muted = PdfColor.fromInt(0xFF5B6478);

class _Brand {
  _Brand(this.regular, this.medium, this.display, this.logo);
  final pw.Font regular;
  final pw.Font medium;
  final pw.Font display;
  final pw.MemoryImage logo;

  static Future<_Brand> load() async {
    Future<pw.Font> font(String f) async => pw.Font.ttf(await rootBundle.load('assets/fonts/$f'));
    final logo = await rootBundle.load('assets/brand/logo.png');
    return _Brand(
      await font('DMSans-Regular.ttf'),
      await font('DMSans-Medium.ttf'),
      await font('Outfit-Bold.ttf'),
      pw.MemoryImage(logo.buffer.asUint8List()),
    );
  }
}

pw.Widget _header(_Brand b, String title, String number, List<(String, String)> facts) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    // The logo PNG is 1200 × 258, so 34 pt high is about 158 pt wide.
    pw.Image(b.logo, height: 34, width: 158),
    pw.Spacer(),
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(font: b.display, fontSize: 24, color: _indigo),
        ),
        pw.Text(
          number,
          style: pw.TextStyle(font: b.medium, fontSize: 11, color: _indigo),
        ),
        pw.SizedBox(height: 6),
        for (final (label, value) in facts)
          pw.Text('$label: $value', style: const pw.TextStyle(fontSize: 9.5, color: _muted)),
      ],
    ),
  ],
);

pw.Widget _band() => pw.Container(height: 4, color: _ochre, margin: const pw.EdgeInsets.symmetric(vertical: 18));

pw.Widget _billTo(_Brand b, String clientName, Contact? contact) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      'FOR',
      style: pw.TextStyle(font: b.medium, fontSize: 8.5, color: _muted, letterSpacing: 1.2),
    ),
    pw.SizedBox(height: 3),
    pw.Text(
      clientName,
      style: pw.TextStyle(font: b.medium, fontSize: 12, color: _indigo),
    ),
    if (contact != null) ...[
      pw.Text(contact.fullName, style: const pw.TextStyle(fontSize: 10)),
      if (contact.email != null) pw.Text(contact.email!, style: const pw.TextStyle(fontSize: 10)),
      if (contact.phone != null) pw.Text(contact.phone!, style: const pw.TextStyle(fontSize: 10)),
    ],
  ],
);

pw.Widget _totalLine(_Brand b, String label, String value, {bool strong = false}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 2),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.SizedBox(
        width: 160,
        child: pw.Text(
          label,
          style: pw.TextStyle(font: strong ? b.medium : b.regular, fontSize: strong ? 12 : 10),
        ),
      ),
      pw.SizedBox(
        width: 110,
        child: pw.Text(
          value,
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            font: strong ? b.medium : b.regular,
            fontSize: strong ? 12 : 10,
            color: strong ? _indigo : null,
          ),
        ),
      ),
    ],
  ),
);

pw.Widget _footer(_Brand b, bool vatRegistered) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Divider(color: _sand, thickness: 1),
    pw.Text(
      'IsangoTech · Your gateway to smarter business · isangotech.co.za',
      style: pw.TextStyle(font: b.medium, fontSize: 8.5, color: _turquoise),
    ),
    if (!vatRegistered)
      pw.Text(
        'IsangoTech is not a registered VAT vendor, so no VAT is charged.',
        style: const pw.TextStyle(fontSize: 8, color: _muted),
      ),
  ],
);

pw.ThemeData _theme(_Brand b) => pw.ThemeData.withFont(base: b.regular, bold: b.medium);

Future<Uint8List> quotePdf(Quote q, Contact? contact, {required bool vatRegistered}) async {
  final b = await _Brand.load();
  final doc = pw.Document(title: 'Quote ${q.number}', author: 'IsangoTech');
  final once = q.lines.where((l) => l.billing == 'once_off').toList();
  final monthly = q.lines.where((l) => l.billing == 'monthly').toList();

  pw.Widget table(String heading, List<QuoteLine> lines) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        heading,
        style: pw.TextStyle(font: b.display, fontSize: 13, color: _indigo),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['Description', 'Qty', 'Unit price', 'Total'],
        data: [
          for (final l in lines) [l.description, '${l.quantity}', money(l.unitPrice), money(l.lineTotal)],
        ],
        headerStyle: pw.TextStyle(font: b.medium, fontSize: 9.5, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: _indigo),
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerAlignments: {
          0: pw.Alignment.centerLeft,
          1: pw.Alignment.centerRight,
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
        },
        cellAlignments: {1: pw.Alignment.centerRight, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
        columnWidths: {
          0: const pw.FlexColumnWidth(5),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(2),
        },
        border: null,
        rowDecoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _sand)),
        ),
      ),
      pw.SizedBox(height: 14),
    ],
  );

  doc.addPage(
    pw.MultiPage(
      theme: _theme(b),
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (_) => _footer(b, vatRegistered),
      build: (_) => [
        _header(b, 'Quote', q.number, [
          ('Date', date(q.sentAt ?? DateTime.now())),
          ('Valid until', date(q.validUntil)),
        ]),
        _band(),
        _billTo(b, q.clientName, contact),
        pw.SizedBox(height: 20),
        if (once.isNotEmpty) table('Once-off', once),
        if (monthly.isNotEmpty) table('Monthly', monthly),
        if (once.isNotEmpty) _totalLine(b, 'Once-off total', money(q.total), strong: true),
        if (monthly.isNotEmpty) _totalLine(b, 'Monthly total', '${money(q.monthlyTotal)} / month', strong: true),
        if (q.notes != null) ...[
          pw.SizedBox(height: 20),
          pw.Text(
            'Notes',
            style: pw.TextStyle(font: b.medium, fontSize: 11, color: _indigo),
          ),
          pw.SizedBox(height: 4),
          pw.Text(q.notes!, style: const pw.TextStyle(fontSize: 10)),
        ],
        pw.SizedBox(height: 24),
        pw.Text(
          'To accept this quote, reply to the email or WhatsApp message it came with. Work starts once the quote is accepted.',
          style: const pw.TextStyle(fontSize: 9.5, color: _muted),
        ),
      ],
    ),
  );
  return doc.save();
}

Future<Uint8List> invoicePdf(Invoice i, Contact? contact, {required bool vatRegistered, String? paymentDetails}) async {
  final b = await _Brand.load();
  final doc = pw.Document(title: 'Invoice ${i.displayNumber}', author: 'IsangoTech');
  doc.addPage(
    pw.MultiPage(
      theme: _theme(b),
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      footer: (_) => _footer(b, vatRegistered),
      build: (_) => [
        _header(b, i.status == 'draft' ? 'Draft invoice' : 'Invoice', i.displayNumber, [
          ('Date', date(i.issueDate ?? DateTime.now())),
          ('Due', date(i.dueDate)),
        ]),
        _band(),
        _billTo(b, i.clientName, contact),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headers: ['Description', 'Amount'],
          data: [
            [i.description ?? '${invoiceTypes[i.type]} invoice', money(i.amount)],
          ],
          headerStyle: pw.TextStyle(font: b.medium, fontSize: 9.5, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: _indigo),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerAlignments: {
            0: pw.Alignment.centerLeft,
            1: pw.Alignment.centerRight,
            2: pw.Alignment.centerRight,
            3: pw.Alignment.centerRight,
          },
          cellAlignments: {1: pw.Alignment.centerRight},
          columnWidths: {0: const pw.FlexColumnWidth(5), 1: const pw.FlexColumnWidth(2)},
          border: null,
        ),
        pw.SizedBox(height: 12),
        _totalLine(b, 'Total', money(i.amount), strong: true),
        if (i.paid > 0) ...[
          _totalLine(b, 'Paid', money(i.paid)),
          _totalLine(b, 'Balance due', money(i.balance), strong: true),
        ],
        pw.SizedBox(height: 24),
        if (paymentDetails != null && paymentDetails.trim().isNotEmpty) ...[
          pw.Text(
            'How to pay',
            style: pw.TextStyle(font: b.medium, fontSize: 11, color: _indigo),
          ),
          pw.SizedBox(height: 4),
          pw.Text(paymentDetails, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 8),
        ],
        pw.Text(
          'Please use ${i.displayNumber} as the payment reference.',
          style: const pw.TextStyle(fontSize: 9.5, color: _muted),
        ),
      ],
    ),
  );
  return doc.save();
}
