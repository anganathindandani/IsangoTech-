// Runs the portal's repository against a real Supabase API (local or a test
// project) with real sign-in and 2FA. Skipped unless these are set:
//   SUPABASE_TEST_URL, SUPABASE_TEST_ANON_KEY, SUPABASE_TEST_SERVICE_KEY
// Never point it at the live project: it creates and changes records.
@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isangotech_portal/data/repository.dart';
import 'package:otp/otp.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final env = Platform.environment;
final url = env['SUPABASE_TEST_URL'];
final anonKey = env['SUPABASE_TEST_ANON_KEY'];
final serviceKey = env['SUPABASE_TEST_SERVICE_KEY'];

/// Makes names and times unique, so the tests can run again on the same database.
final runId = DateTime.now().millisecondsSinceEpoch;

String totp(String secret) => OTP.generateTOTPCodeString(
  secret,
  DateTime.now().millisecondsSinceEpoch,
  algorithm: Algorithm.SHA1,
  isGoogle: true,
);

void main() {
  final skip = url == null || anonKey == null || serviceKey == null
      ? 'Set SUPABASE_TEST_URL, SUPABASE_TEST_ANON_KEY and SUPABASE_TEST_SERVICE_KEY to run'
      : false;

  late SupabaseClient client;
  late Repository repo;

  setUpAll(() async {
    if (skip != false) return;
    final admin = SupabaseClient(url!, serviceKey!, authOptions: const AuthClientOptions(autoRefreshToken: false));
    final email = 'admin-${DateTime.now().millisecondsSinceEpoch}@isangotech.test';
    const password = 'Test-Password-123';
    final user = (await admin.auth.admin.createUser(
      AdminUserAttributes(email: email, password: password, emailConfirm: true),
    )).user!;
    await admin.from('team_members').insert({
      'id': user.id,
      'full_name': 'Test Admin',
      'role': 'admin',
      'email': email,
    });

    client = SupabaseClient(url!, anonKey!, authOptions: const AuthClientOptions(autoRefreshToken: false));
    repo = Repository(client);
    await client.auth.signInWithPassword(email: email, password: password);

    // Before 2FA the database shows nothing, even to an admin.
    expect(await repo.me(), isNull, reason: 'aal1 sessions must not see team records');

    final enrolment = await client.auth.mfa.enroll(factorType: FactorType.totp, friendlyName: 'Test phone');
    await client.auth.mfa.challengeAndVerify(factorId: enrolment.id, code: totp(enrolment.totp!.secret));
    expect(client.auth.mfa.getAuthenticatorAssuranceLevel().currentLevel, AuthenticatorAssuranceLevels.aal2);
  });

  test('admin profile is visible after 2FA', () async {
    final me = await repo.me();
    expect(me?.role, 'admin');
  }, skip: skip);

  test('lead → client → quote → approval → invoice → payment', () async {
    final industries = await repo.industries();
    expect(industries.first.name, 'Salons and beauty');

    final leadId = await repo.addLead(
      fullName: 'Nomsa Khumalo',
      businessName: 'Nomsa Nails',
      industryId: industries.first.id,
      phone: '0825551234',
      source: 'whatsapp',
      stageNeeded: 1,
      biggestPain: 'No website',
      whatsappOptIn: true,
    );
    final consents = await repo.consents(leadId: leadId);
    expect(consents.map((c) => c.purpose).toSet(), {'enquiry', 'whatsapp'});
    expect(consents.first.source, 'whatsapp');

    expect((await repo.leads(search: 'nomsa')).map((l) => l.id), contains(leadId));
    expect((await repo.leads(openOnly: true)).map((l) => l.id), contains(leadId));
    expect((await repo.lead(leadId)).industryName, 'Salons and beauty');

    await repo.addActivity(leadId: leadId, type: 'call', summary: 'Called back, wants a website');
    final acts = await repo.activities(leadId: leadId);
    expect(acts.single.byName, 'Test Admin');

    await repo.updateLead(leadId, {'next_follow_up': '2000-01-01', 'pipeline_stage': 'contacted'});
    expect((await repo.followUpsDue()).map((l) => l.id), contains(leadId));

    // Quote for the lead creates the prospect client.
    final quoteId = await repo.createQuoteForLead(leadId);
    var quote = await repo.quote(quoteId);
    expect(quote.status, 'draft');
    expect(quote.clientName, 'Nomsa Nails');
    expect(quote.number, matches(RegExp(r'^Q-\d{4}-\d{4}$')));
    final clientId = quote.clientId;
    expect((await repo.client(clientId)).status, 'prospect');
    expect((await repo.contacts(clientId)).single.isPrimary, isTrue);

    await repo.addQuoteLine(
      quoteId,
      description: 'Starter website',
      quantity: 1,
      unitPrice: 18000,
      billing: 'once_off',
    );
    await repo.addQuoteLine(
      quoteId,
      description: 'Care plan',
      quantity: 1,
      unitPrice: 650,
      billing: 'monthly',
      sortOrder: 1,
    );
    quote = await repo.quote(quoteId);
    expect(quote.total, 18000);
    expect(quote.monthlyTotal, 650);
    expect(quote.lines.length, 2);

    // 18 000 + 12 × 650 = 25 800, above the R20 000 approval amount.
    await expectLater(repo.setQuoteStatus(quoteId, 'sent'), throwsA(isA<PostgrestException>()));
    await repo.setQuoteStatus(quoteId, 'pending_approval');
    await repo.approveQuote(quoteId);
    await repo.setQuoteStatus(quoteId, 'sent');
    expect((await repo.lead(leadId)).pipelineStage, 'quoted');
    await expectLater(
      repo.updateQuoteLine(quote.lines.first.id, {'unit_price': 1}),
      throwsA(isA<PostgrestException>()),
    );
    await repo.setQuoteStatus(quoteId, 'accepted');
    expect((await repo.client(clientId)).status, 'active');
    expect((await repo.lead(leadId)).pipelineStage, 'won');
    expect((await repo.quotes(clientId: clientId)).single.status, 'accepted');

    // Setup invoice from the quote, sent, part paid, then paid.
    final invoiceId = await repo.invoiceFromQuote(await repo.quote(quoteId));
    var invoice = await repo.invoice(invoiceId);
    expect(invoice.paymentStatus, 'draft');
    expect(invoice.amount, 18000);
    await repo.updateInvoice(invoiceId, {'status': 'sent'});
    invoice = await repo.invoice(invoiceId);
    expect(invoice.number, matches(RegExp(r'^INV-\d{4}-\d{4}$')));
    expect(invoice.paymentStatus, 'unpaid');
    await repo.recordPayment(invoiceId, amount: 9000, paidOn: DateTime.now(), method: 'eft', reference: 'Deposit');
    invoice = await repo.invoice(invoiceId);
    expect(invoice.paymentStatus, 'part_paid');
    expect(invoice.balance, 9000);
    expect(invoice.payments.single.reference, 'Deposit');
    await expectLater(
      repo.recordPayment(invoiceId, amount: 10000, paidOn: DateTime.now(), method: 'eft'),
      throwsA(isA<PostgrestException>()),
    );
    await repo.recordPayment(invoiceId, amount: 9000, paidOn: DateTime.now(), method: 'eft');
    expect((await repo.invoice(invoiceId)).paymentStatus, 'paid');
    expect((await repo.invoices(clientId: clientId)).single.clientName, 'Nomsa Nails');

    // Growth stage history.
    await repo.updateClient(clientId, {'growth_stage': 2});
    expect((await repo.stageChanges(clientId)).map((s) => s.toStage), [1, 2]);
  }, skip: skip);

  test('booking slots and assessments', () async {
    // A slot at a minute no other run will use, about a year out.
    final start = DateTime.utc(2027, 1, 1).add(Duration(minutes: (runId ~/ 1000) % 500000 * 2));
    await repo.addSlot(startsAt: start, endsAt: start.add(const Duration(minutes: 1)), mode: 'online');
    final slot = (await repo.slots(status: 'open')).firstWhere((s) => s.startsAt.isAtSameMomentAs(start));

    final leadId = await repo.addLead(
      fullName: 'Ayanda Caters',
      phone: '0731112222',
      source: 'phone',
      whatsappOptIn: false,
    );
    await repo.bookAssessment(leadId: leadId, slotId: slot.id);
    expect((await repo.lead(leadId)).pipelineStage, 'assessment');
    final booked = (await repo.assessments(leadId: leadId)).single;
    expect(booked.scheduledAt!.isAtSameMomentAs(start), isTrue);
    expect(booked.whoName, 'Ayanda Caters');
    expect((await repo.assessments(upcomingOnly: true)).map((a) => a.id), contains(booked.id));

    await repo.updateAssessment(booked.id, {'status': 'completed', 'findings': 'Ready for a booking system'});
    expect((await repo.assessments(leadId: leadId)).single.findings, 'Ready for a booking system');
  }, skip: skip);

  test('price list, contacts, settings and audit log', () async {
    final packageName = 'Test package $runId';
    await repo.savePackage({'name': packageName, 'growth_stage': 2, 'price': 1234.5, 'billing': 'once_off'});
    final pkg = (await repo.packages()).firstWhere((p) => p.name == packageName);
    expect(pkg.price, 1234.5);
    await repo.savePackage({'active': false}, id: pkg.id);
    expect((await repo.packages(activeOnly: true)).map((p) => p.id), isNot(contains(pkg.id)));

    final clientId = await repo.addClient({
      'business_name': 'Buffalo City Bakery $runId',
      'growth_stage': 3,
      'status': 'prospect',
    });
    await repo.saveContact(clientId, {'full_name': 'Sipho Ndlovu', 'phone': '0821239876', 'is_primary': true});
    final contact = (await repo.contacts(clientId)).single;
    await repo.saveContact(clientId, {'role': 'Owner'}, id: contact.id);
    expect((await repo.contacts(clientId)).single.role, 'Owner');
    expect((await repo.clients(search: 'bakery $runId')).single.id, clientId);

    await repo.updateSetting('quote_valid_days', 45);
    expect((await repo.settings()).firstWhere((s) => s.key == 'quote_valid_days').value, 45);
    await repo.updateSetting('quote_valid_days', 30);

    await repo.logExport('clients', [clientId]);
    final audit = await repo.auditLog();
    expect(audit.any((a) => a.action == 'export' && a.recordId == clientId && a.byName == 'Test Admin'), isTrue);
    expect(
      audit.any((a) => a.tableName == 'contacts' && a.action == 'update' && a.changedFields!.contains('role')),
      isTrue,
    );
  }, skip: skip);
}
