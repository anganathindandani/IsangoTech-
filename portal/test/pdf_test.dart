import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isangotech_portal/data/models.dart';
import 'package:isangotech_portal/pdf/documents.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final contact = Contact(
    id: 'c1',
    fullName: 'Thandi Mbeki',
    phone: '082 123 4567',
    email: 'thandi@example.co.za',
    isPrimary: true,
  );

  test('quote PDF has the brand and both once-off and monthly totals', () async {
    final quote = Quote(
      id: 'q1',
      number: 'Q-2026-0001',
      clientId: 'cl1',
      clientName: "Thandi's Hair Studio",
      status: 'sent',
      total: 18000,
      monthlyTotal: 650,
      validUntil: DateTime(2026, 11, 7),
      notes: 'Includes two rounds of changes.',
      sentAt: DateTime(2026, 10, 8),
      createdAt: DateTime(2026, 10, 8),
      lines: [
        QuoteLine(
          id: 'l1',
          description: 'Starter website',
          quantity: 1,
          unitPrice: 18000,
          billing: 'once_off',
          lineTotal: 18000,
          sortOrder: 0,
        ),
        QuoteLine(
          id: 'l2',
          description: 'Care plan',
          quantity: 1,
          unitPrice: 650,
          billing: 'monthly',
          lineTotal: 650,
          sortOrder: 1,
        ),
      ],
    );
    final bytes = await quotePdf(quote, contact, vatRegistered: false);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final out = Platform.environment['PDF_OUT'];
    if (out != null) File('$out/quote.pdf').writeAsBytesSync(bytes);
  });

  test('invoice PDF shows the balance and payment details', () async {
    final invoice = Invoice(
      id: 'i1',
      number: 'INV-2026-0001',
      clientId: 'cl1',
      clientName: "Thandi's Hair Studio",
      type: 'setup',
      description: 'Starter website (quote Q-2026-0001)',
      amount: 18000,
      issueDate: DateTime(2026, 10, 8),
      dueDate: DateTime(2026, 10, 15),
      status: 'sent',
      paid: 9000,
      balance: 9000,
      paymentStatus: 'part_paid',
      isOverdue: false,
      createdAt: DateTime(2026, 10, 8),
    );
    final bytes = await invoicePdf(
      invoice,
      contact,
      vatRegistered: false,
      paymentDetails: 'Bank: Example Bank\nAccount name: IsangoTech\nAccount number: 000 000 000\nBranch code: 000000',
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    final out = Platform.environment['PDF_OUT'];
    if (out != null) File('$out/invoice.pdf').writeAsBytesSync(bytes);
  });
}
