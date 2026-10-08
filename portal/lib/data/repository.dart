import 'package:supabase_flutter/supabase_flutter.dart';

import '../format.dart';
import 'models.dart';

/// Every database call the portal makes. Row-level security in the database
/// decides what the signed-in person may see and change; this class only
/// shapes the requests.
class Repository {
  Repository(this.db);
  final SupabaseClient db;

  String? get userId => db.auth.currentUser?.id;

  // ---------------------------------------------------------------- team

  /// The signed-in person's team record, or null if they have no portal access.
  Future<TeamMember?> me() async {
    final id = userId;
    if (id == null) return null;
    final row = await db.from('team_members').select().eq('id', id).maybeSingle();
    return row == null ? null : TeamMember.fromJson(row);
  }

  // ---------------------------------------------------------------- lookups

  Future<List<Industry>> industries() async {
    final rows = await db
        .from('industries')
        .select('id, name')
        .eq('active', true)
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return rows.map(Industry.fromJson).toList();
  }

  Future<Map<String, dynamic>> settingsMap() async {
    final rows = await db.from('settings').select('key, value');
    return {for (final r in rows) r['key'] as String: r['value']};
  }

  // ---------------------------------------------------------------- leads

  Future<List<Lead>> leads({String? pipelineStage, bool openOnly = false, String? search}) async {
    var q = db.from('leads').select(Lead.select).isFilter('anonymised_at', null);
    if (pipelineStage != null) q = q.eq('pipeline_stage', pipelineStage);
    if (openOnly) q = q.not('pipeline_stage', 'in', '(won,lost)');
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim().replaceAll(RegExp(r'[,()]'), ' ');
      q = q.or('full_name.ilike.*$s*,business_name.ilike.*$s*,phone.ilike.*$s*,email.ilike.*$s*');
    }
    final rows = await q.order('created_at', ascending: false).limit(200);
    return rows.map(Lead.fromJson).toList();
  }

  Future<Lead> lead(String id) async => Lead.fromJson(await db.from('leads').select(Lead.select).eq('id', id).single());

  /// Quick add for WhatsApp, walk-in and phone enquiries. Records the consent
  /// the person gave, with the current privacy policy version.
  Future<String> addLead({
    required String fullName,
    String? businessName,
    String? industryId,
    String? phone,
    String? email,
    required String source,
    int? stageNeeded,
    String? biggestPain,
    required bool whatsappOptIn,
  }) async {
    final row = await db
        .from('leads')
        .insert({
          'full_name': fullName,
          'business_name': _blankToNull(businessName),
          'industry_id': industryId,
          'phone': _blankToNull(phone),
          'email': _blankToNull(email),
          'source': source,
          'stage_needed': stageNeeded,
          'biggest_pain': _blankToNull(biggestPain),
        })
        .select('id')
        .single();
    final leadId = row['id'] as String;
    final settings = await settingsMap();
    final policy = '${settings['privacy_policy_version'] ?? '1'}';
    final consentSource = source == 'whatsapp' ? 'whatsapp' : 'in_person';
    await db.from('consents').insert([
      {'lead_id': leadId, 'purpose': 'enquiry', 'privacy_policy_version': policy, 'source': consentSource},
      if (whatsappOptIn)
        {'lead_id': leadId, 'purpose': 'whatsapp', 'privacy_policy_version': policy, 'source': consentSource},
    ]);
    return leadId;
  }

  Future<void> updateLead(String id, Map<String, dynamic> changes) => db.from('leads').update(changes).eq('id', id);

  Future<List<Activity>> activities({String? leadId, String? clientId}) async {
    var q = db.from('lead_activities').select(Activity.select);
    if (leadId != null) q = q.eq('lead_id', leadId);
    if (clientId != null) q = q.eq('client_id', clientId);
    final rows = await q.order('occurred_at', ascending: false);
    return rows.map(Activity.fromJson).toList();
  }

  Future<void> addActivity({String? leadId, String? clientId, required String type, required String summary}) =>
      db.from('lead_activities').insert({'lead_id': leadId, 'client_id': clientId, 'type': type, 'summary': summary});

  Future<List<Consent>> consents({String? leadId, String? contactId}) async {
    var q = db.from('consents').select();
    if (leadId != null) q = q.eq('lead_id', leadId);
    if (contactId != null) q = q.eq('contact_id', contactId);
    final rows = await q.order('given_at', ascending: true);
    return rows.map(Consent.fromJson).toList();
  }

  Future<void> withdrawConsent(String id) =>
      db.from('consents').update({'withdrawn_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

  /// Creates (or returns) the prospect client for a lead.
  Future<String> convertLeadToClient(String leadId) async =>
      await db.rpc('convert_lead_to_client', params: {'p_lead_id': leadId}) as String;

  // ---------------------------------------------------------------- clients

  Future<List<Client>> clients({String? status, String? search}) async {
    var q = db.from('clients').select(Client.select).isFilter('anonymised_at', null);
    if (status != null) q = q.eq('status', status);
    if (search != null && search.trim().isNotEmpty) {
      q = q.ilike('business_name', '*${search.trim()}*');
    }
    final rows = await q.order('business_name', ascending: true).limit(500);
    return rows.map(Client.fromJson).toList();
  }

  Future<Client> client(String id) async =>
      Client.fromJson(await db.from('clients').select(Client.select).eq('id', id).single());

  Future<String> addClient(Map<String, dynamic> values) async =>
      (await db.from('clients').insert(values).select('id').single())['id'] as String;

  Future<void> updateClient(String id, Map<String, dynamic> changes) => db.from('clients').update(changes).eq('id', id);

  Future<List<Contact>> contacts(String clientId) async {
    final rows = await db
        .from('contacts')
        .select()
        .eq('client_id', clientId)
        .order('is_primary', ascending: false)
        .order('full_name', ascending: true);
    return rows.map(Contact.fromJson).toList();
  }

  Future<void> saveContact(String clientId, Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      await db.from('contacts').insert({...values, 'client_id': clientId});
    } else {
      await db.from('contacts').update(values).eq('id', id);
    }
  }

  Future<void> deleteContact(String id) => db.from('contacts').delete().eq('id', id);

  Future<List<StageChange>> stageChanges(String clientId) async {
    final rows = await db.from('stage_changes').select().eq('client_id', clientId).order('changed_at', ascending: true);
    return rows.map(StageChange.fromJson).toList();
  }

  // ---------------------------------------------------------------- price list

  Future<List<Package>> packages({bool activeOnly = false}) async {
    var q = db.from('packages').select();
    if (activeOnly) q = q.eq('active', true);
    final rows = await q.order('growth_stage', ascending: true, nullsFirst: false).order('name', ascending: true);
    return rows.map(Package.fromJson).toList();
  }

  Future<void> savePackage(Map<String, dynamic> values, {String? id}) async {
    if (id == null) {
      await db.from('packages').insert(values);
    } else {
      await db.from('packages').update(values).eq('id', id);
    }
  }

  // ---------------------------------------------------------------- assessments

  Future<List<BookingSlot>> slots({bool upcomingOnly = true, String? status}) async {
    var q = db.from('booking_slots').select();
    if (upcomingOnly) q = q.gte('starts_at', DateTime.now().toUtc().toIso8601String());
    if (status != null) q = q.eq('status', status);
    final rows = await q.order('starts_at', ascending: true);
    return rows.map(BookingSlot.fromJson).toList();
  }

  Future<void> addSlot({
    required DateTime startsAt,
    required DateTime endsAt,
    required String mode,
    String? location,
  }) => db.from('booking_slots').insert({
    'starts_at': startsAt.toUtc().toIso8601String(),
    'ends_at': endsAt.toUtc().toIso8601String(),
    'mode': mode,
    'location': _blankToNull(location),
  });

  Future<void> cancelSlot(String id) => db.from('booking_slots').update({'status': 'cancelled'}).eq('id', id);

  Future<List<Assessment>> assessments({String? leadId, String? clientId, bool upcomingOnly = false}) async {
    var q = db.from('assessments').select(Assessment.select);
    if (leadId != null) q = q.eq('lead_id', leadId);
    if (clientId != null) q = q.eq('client_id', clientId);
    if (upcomingOnly) {
      q = q.eq('status', 'booked').gte('scheduled_at', DateTime.now().toUtc().toIso8601String());
    }
    final rows = await q.order('scheduled_at', ascending: upcomingOnly);
    return rows.map(Assessment.fromJson).toList();
  }

  Future<void> bookAssessment({String? leadId, String? clientId, required String slotId}) async {
    await db.from('assessments').insert({'lead_id': leadId, 'client_id': clientId, 'booking_slot_id': slotId});
    if (leadId != null) {
      await db.from('leads').update({'pipeline_stage': 'assessment'}).eq('id', leadId).inFilter('pipeline_stage', [
        'new',
        'contacted',
      ]);
    }
  }

  Future<void> updateAssessment(String id, Map<String, dynamic> changes) =>
      db.from('assessments').update(changes).eq('id', id);

  // ---------------------------------------------------------------- quotes

  Future<List<Quote>> quotes({String? status, String? clientId}) async {
    var q = db.from('quotes').select(Quote.select);
    if (status != null) q = q.eq('status', status);
    if (clientId != null) q = q.eq('client_id', clientId);
    final rows = await q.order('created_at', ascending: false).limit(200);
    return rows.map(Quote.fromJson).toList();
  }

  Future<Quote> quote(String id) async =>
      Quote.fromJson(await db.from('quotes').select(Quote.selectWithLines).eq('id', id).single());

  Future<String> createQuote({required String clientId, String? leadId}) async =>
      (await db.from('quotes').insert({'client_id': clientId, 'lead_id': leadId}).select('id').single())['id']
          as String;

  /// Converts the lead to a prospect client if needed, then starts a draft quote.
  Future<String> createQuoteForLead(String leadId) async {
    final clientId = await convertLeadToClient(leadId);
    return createQuote(clientId: clientId, leadId: leadId);
  }

  Future<void> updateQuote(String id, Map<String, dynamic> changes) => db.from('quotes').update(changes).eq('id', id);

  Future<void> setQuoteStatus(String id, String status) => updateQuote(id, {'status': status});

  Future<void> approveQuote(String id) => updateQuote(id, {'approved_at': DateTime.now().toUtc().toIso8601String()});

  Future<void> addQuoteLine(
    String quoteId, {
    String? packageId,
    required String description,
    required num quantity,
    required num unitPrice,
    required String billing,
    int sortOrder = 0,
  }) => db.from('quote_line_items').insert({
    'quote_id': quoteId,
    'package_id': packageId,
    'description': description,
    'quantity': quantity,
    'unit_price': unitPrice,
    'billing': billing,
    'sort_order': sortOrder,
  });

  Future<void> updateQuoteLine(String id, Map<String, dynamic> changes) =>
      db.from('quote_line_items').update(changes).eq('id', id);

  Future<void> deleteQuoteLine(String id) => db.from('quote_line_items').delete().eq('id', id);

  // ---------------------------------------------------------------- invoices

  Future<List<Invoice>> invoices({String? paymentStatus, bool overdueOnly = false, String? clientId}) async {
    var q = db.from('invoice_summaries').select(Invoice.select);
    if (paymentStatus != null) q = q.eq('payment_status', paymentStatus);
    if (overdueOnly) q = q.eq('is_overdue', true);
    if (clientId != null) q = q.eq('client_id', clientId);
    final rows = await q.order('created_at', ascending: false).limit(300);
    return rows.map(Invoice.fromJson).toList();
  }

  Future<Invoice> invoice(String id) async =>
      Invoice.fromJson(await db.from('invoice_summaries').select(Invoice.selectWithPayments).eq('id', id).single());

  Future<String> createInvoice({
    required String clientId,
    required String type,
    required num amount,
    String? description,
    String? quoteId,
    DateTime? dueDate,
  }) async =>
      (await db
              .from('invoices')
              .insert({
                'client_id': clientId,
                'type': type,
                'amount': amount,
                'description': _blankToNull(description),
                'quote_id': quoteId,
                'due_date': dueDate == null ? null : isoDate(dueDate),
              })
              .select('id')
              .single())['id']
          as String;

  /// Setup invoice for the once-off part of an accepted quote.
  Future<String> invoiceFromQuote(Quote q) => createInvoice(
    clientId: q.clientId,
    type: 'setup',
    amount: q.total,
    description: 'Quote ${q.number}',
    quoteId: q.id,
  );

  Future<void> updateInvoice(String id, Map<String, dynamic> changes) =>
      db.from('invoices').update(changes).eq('id', id);

  Future<void> deleteDraftInvoice(String id) => db.from('invoices').delete().eq('id', id).eq('status', 'draft');

  Future<void> recordPayment(
    String invoiceId, {
    required num amount,
    required DateTime paidOn,
    required String method,
    String? reference,
  }) => db.from('payments').insert({
    'invoice_id': invoiceId,
    'amount': amount,
    'paid_on': isoDate(paidOn),
    'method': method,
    'reference': _blankToNull(reference),
  });

  // ---------------------------------------------------------------- settings and audit

  Future<List<Setting>> settings() async {
    final rows = await db.from('settings').select().order('key', ascending: true);
    return rows.map(Setting.fromJson).toList();
  }

  Future<void> updateSetting(String key, dynamic value) => db.from('settings').update({'value': value}).eq('key', key);

  Future<List<AuditEntry>> auditLog({String? table, int limit = 200}) async {
    var q = db.from('audit_log').select('*, team_members(full_name)');
    if (table != null) q = q.eq('table_name', table);
    final rows = await q.order('changed_at', ascending: false).limit(limit);
    return rows.map(AuditEntry.fromJson).toList();
  }

  Future<void> logExport(String table, List<String> ids) =>
      db.rpc('log_export', params: {'p_table': table, 'p_record_ids': ids});

  // ---------------------------------------------------------------- home

  Future<List<Lead>> followUpsDue() async {
    final rows = await db
        .from('leads')
        .select(Lead.select)
        .not('pipeline_stage', 'in', '(won,lost)')
        .lte('next_follow_up', isoDate(DateTime.now()))
        .order('next_follow_up', ascending: true);
    return rows.map(Lead.fromJson).toList();
  }

  static String? _blankToNull(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
}
