import '../format.dart';

class TeamMember {
  TeamMember({required this.id, required this.fullName, required this.role, required this.email, required this.active});
  final String id;
  final String fullName;
  final String role;
  final String email;
  final bool active;

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    id: j['id'],
    fullName: j['full_name'],
    role: j['role'],
    email: j['email'],
    active: j['active'] ?? true,
  );
}

class Industry {
  Industry({required this.id, required this.name});
  final String id;
  final String name;

  factory Industry.fromJson(Map<String, dynamic> j) => Industry(id: j['id'], name: j['name']);
}

class Lead {
  Lead({
    required this.id,
    required this.fullName,
    this.businessName,
    this.industryId,
    this.industryName,
    this.phone,
    this.email,
    required this.source,
    this.stageNeeded,
    this.biggestPain,
    required this.pipelineStage,
    this.lostReason,
    this.nextFollowUp,
    this.clientId,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String? businessName;
  final String? industryId;
  final String? industryName;
  final String? phone;
  final String? email;
  final String source;
  final int? stageNeeded;
  final String? biggestPain;
  final String pipelineStage;
  final String? lostReason;
  final DateTime? nextFollowUp;
  final String? clientId;
  final DateTime createdAt;

  static const select = '*, industries(name)';

  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
    id: j['id'],
    fullName: j['full_name'],
    businessName: j['business_name'],
    industryId: j['industry_id'],
    industryName: (j['industries'] as Map?)?['name'],
    phone: j['phone'],
    email: j['email'],
    source: j['source'],
    stageNeeded: j['stage_needed'],
    biggestPain: j['biggest_pain'],
    pipelineStage: j['pipeline_stage'],
    lostReason: j['lost_reason'],
    nextFollowUp: parseDate(j['next_follow_up']),
    clientId: j['client_id'],
    createdAt: DateTime.parse(j['created_at']),
  );

  String get displayName => businessName == null || businessName!.isEmpty ? fullName : '$fullName · $businessName';
}

class Activity {
  Activity({required this.id, required this.type, required this.summary, required this.occurredAt, this.byName});
  final String id;
  final String type;
  final String summary;
  final DateTime occurredAt;
  final String? byName;

  static const select = '*, team_members!lead_activities_created_by_fkey(full_name)';

  factory Activity.fromJson(Map<String, dynamic> j) => Activity(
    id: j['id'],
    type: j['type'],
    summary: j['summary'],
    occurredAt: DateTime.parse(j['occurred_at']),
    byName: (j['team_members'] as Map?)?['full_name'],
  );
}

class Consent {
  Consent({
    required this.id,
    required this.purpose,
    required this.givenAt,
    required this.policyVersion,
    required this.source,
    this.withdrawnAt,
  });
  final String id;
  final String purpose;
  final DateTime givenAt;
  final String policyVersion;
  final String source;
  final DateTime? withdrawnAt;

  factory Consent.fromJson(Map<String, dynamic> j) => Consent(
    id: j['id'],
    purpose: j['purpose'],
    givenAt: DateTime.parse(j['given_at']),
    policyVersion: j['privacy_policy_version'],
    source: j['source'],
    withdrawnAt: parseDate(j['withdrawn_at']),
  );
}

class Client {
  Client({
    required this.id,
    required this.businessName,
    this.industryId,
    this.industryName,
    this.address,
    this.growthStage,
    this.nextStageReviewDate,
    required this.status,
    this.startDate,
    this.systemsUsed,
    this.notes,
  });

  final String id;
  final String businessName;
  final String? industryId;
  final String? industryName;
  final String? address;
  final int? growthStage;
  final DateTime? nextStageReviewDate;
  final String status;
  final DateTime? startDate;
  final String? systemsUsed;
  final String? notes;

  static const select = '*, industries(name)';

  factory Client.fromJson(Map<String, dynamic> j) => Client(
    id: j['id'],
    businessName: j['business_name'],
    industryId: j['industry_id'],
    industryName: (j['industries'] as Map?)?['name'],
    address: j['address'],
    growthStage: j['growth_stage'],
    nextStageReviewDate: parseDate(j['next_stage_review_date']),
    status: j['status'],
    startDate: parseDate(j['start_date']),
    systemsUsed: j['systems_used'],
    notes: j['notes'],
  );
}

class Contact {
  Contact({required this.id, required this.fullName, this.role, this.phone, this.email, required this.isPrimary});
  final String id;
  final String fullName;
  final String? role;
  final String? phone;
  final String? email;
  final bool isPrimary;

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
    id: j['id'],
    fullName: j['full_name'],
    role: j['role'],
    phone: j['phone'],
    email: j['email'],
    isPrimary: j['is_primary'] ?? false,
  );
}

class StageChange {
  StageChange({this.fromStage, this.toStage, required this.changedAt});
  final int? fromStage;
  final int? toStage;
  final DateTime changedAt;

  factory StageChange.fromJson(Map<String, dynamic> j) =>
      StageChange(fromStage: j['from_stage'], toStage: j['to_stage'], changedAt: DateTime.parse(j['changed_at']));
}

class Package {
  Package({
    required this.id,
    required this.name,
    this.growthStage,
    this.description,
    required this.price,
    required this.billing,
    required this.active,
  });
  final String id;
  final String name;
  final int? growthStage;
  final String? description;
  final num price;
  final String billing;
  final bool active;

  factory Package.fromJson(Map<String, dynamic> j) => Package(
    id: j['id'],
    name: j['name'],
    growthStage: j['growth_stage'],
    description: j['description'],
    price: parseNum(j['price']),
    billing: j['billing'],
    active: j['active'] ?? true,
  );
}

class BookingSlot {
  BookingSlot({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.mode,
    this.location,
    required this.status,
  });
  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String mode;
  final String? location;
  final String status;

  factory BookingSlot.fromJson(Map<String, dynamic> j) => BookingSlot(
    id: j['id'],
    startsAt: DateTime.parse(j['starts_at']),
    endsAt: DateTime.parse(j['ends_at']),
    mode: j['mode'],
    location: j['location'],
    status: j['status'],
  );

  String get label => '${dateTime(startsAt)} · ${mode == 'online' ? 'Online' : location ?? 'In person'}';
}

class Assessment {
  Assessment({
    required this.id,
    this.leadId,
    this.clientId,
    this.whoName,
    this.scheduledAt,
    this.location,
    required this.status,
    this.notes,
    this.findings,
    this.recommendedPackageId,
  });
  final String id;
  final String? leadId;
  final String? clientId;
  final String? whoName;
  final DateTime? scheduledAt;
  final String? location;
  final String status;
  final String? notes;
  final String? findings;
  final String? recommendedPackageId;

  static const select = '*, leads(full_name, business_name), clients(business_name)';

  factory Assessment.fromJson(Map<String, dynamic> j) {
    final lead = j['leads'] as Map?;
    final client = j['clients'] as Map?;
    return Assessment(
      id: j['id'],
      leadId: j['lead_id'],
      clientId: j['client_id'],
      whoName: client?['business_name'] ?? lead?['business_name'] ?? lead?['full_name'],
      scheduledAt: parseDate(j['scheduled_at']),
      location: j['location'],
      status: j['status'],
      notes: j['notes'],
      findings: j['findings'],
      recommendedPackageId: j['recommended_package_id'],
    );
  }
}

class QuoteLine {
  QuoteLine({
    required this.id,
    this.packageId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.billing,
    required this.lineTotal,
    required this.sortOrder,
  });
  final String id;
  final String? packageId;
  final String description;
  final num quantity;
  final num unitPrice;
  final String billing;
  final num lineTotal;
  final int sortOrder;

  factory QuoteLine.fromJson(Map<String, dynamic> j) => QuoteLine(
    id: j['id'],
    packageId: j['package_id'],
    description: j['description'],
    quantity: parseNum(j['quantity']),
    unitPrice: parseNum(j['unit_price']),
    billing: j['billing'],
    lineTotal: parseNum(j['line_total']),
    sortOrder: j['sort_order'] ?? 0,
  );
}

class Quote {
  Quote({
    required this.id,
    required this.number,
    required this.clientId,
    required this.clientName,
    this.leadId,
    required this.status,
    required this.total,
    required this.monthlyTotal,
    this.validUntil,
    this.notes,
    this.approvedAt,
    this.sentAt,
    required this.createdAt,
    this.lines = const [],
  });
  final String id;
  final String number;
  final String clientId;
  final String clientName;
  final String? leadId;
  final String status;
  final num total;
  final num monthlyTotal;
  final DateTime? validUntil;
  final String? notes;
  final DateTime? approvedAt;
  final DateTime? sentAt;
  final DateTime createdAt;
  final List<QuoteLine> lines;

  static const select = '*, clients(business_name)';
  static const selectWithLines = '*, clients(business_name), quote_line_items(*)';

  bool get editable => status == 'draft' || status == 'pending_approval';
  num get firstYearValue => total + 12 * monthlyTotal;

  factory Quote.fromJson(Map<String, dynamic> j) {
    final lines = ((j['quote_line_items'] as List?) ?? []).map((l) => QuoteLine.fromJson(l)).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Quote(
      id: j['id'],
      number: j['number'],
      clientId: j['client_id'],
      clientName: (j['clients'] as Map?)?['business_name'] ?? '',
      leadId: j['lead_id'],
      status: j['status'],
      total: parseNum(j['total']),
      monthlyTotal: parseNum(j['monthly_total']),
      validUntil: parseDate(j['valid_until']),
      notes: j['notes'],
      approvedAt: parseDate(j['approved_at']),
      sentAt: parseDate(j['sent_at']),
      createdAt: DateTime.parse(j['created_at']),
      lines: lines,
    );
  }
}

class Payment {
  Payment({required this.id, required this.amount, required this.paidOn, required this.method, this.reference});
  final String id;
  final num amount;
  final DateTime paidOn;
  final String method;
  final String? reference;

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id: j['id'],
    amount: parseNum(j['amount']),
    paidOn: DateTime.parse(j['paid_on']),
    method: j['method'],
    reference: j['reference'],
  );
}

class Invoice {
  Invoice({
    required this.id,
    this.number,
    required this.clientId,
    required this.clientName,
    this.quoteId,
    required this.type,
    this.description,
    required this.amount,
    this.issueDate,
    this.dueDate,
    required this.status,
    required this.paid,
    required this.balance,
    required this.paymentStatus,
    required this.isOverdue,
    required this.createdAt,
    this.payments = const [],
  });
  final String id;
  final String? number;
  final String clientId;
  final String clientName;
  final String? quoteId;
  final String type;
  final String? description;
  final num amount;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String status;
  final num paid;
  final num balance;
  final String paymentStatus;
  final bool isOverdue;
  final DateTime createdAt;
  final List<Payment> payments;

  /// Read from the invoice_summaries view, which adds paid, balance and status.
  static const select = '*, clients(business_name)';
  static const selectWithPayments = '*, clients(business_name), payments(*)';

  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(
    id: j['id'],
    number: j['number'],
    clientId: j['client_id'],
    clientName: (j['clients'] as Map?)?['business_name'] ?? '',
    quoteId: j['quote_id'],
    type: j['type'],
    description: j['description'],
    amount: parseNum(j['amount']),
    issueDate: parseDate(j['issue_date']),
    dueDate: parseDate(j['due_date']),
    status: j['status'],
    paid: parseNum(j['paid']),
    balance: parseNum(j['balance']),
    paymentStatus: j['payment_status'],
    isOverdue: j['is_overdue'] == true,
    createdAt: DateTime.parse(j['created_at']),
    payments: ((j['payments'] as List?) ?? []).map((p) => Payment.fromJson(p)).toList()
      ..sort((a, b) => a.paidOn.compareTo(b.paidOn)),
  );

  String get displayNumber => number ?? 'Draft';
}

class Setting {
  Setting({required this.key, required this.value, this.description, this.updatedAt});
  final String key;
  final dynamic value;
  final String? description;
  final DateTime? updatedAt;

  factory Setting.fromJson(Map<String, dynamic> j) =>
      Setting(key: j['key'], value: j['value'], description: j['description'], updatedAt: parseDate(j['updated_at']));
}

class AuditEntry {
  AuditEntry({
    required this.id,
    required this.tableName,
    this.recordId,
    required this.action,
    this.changedFields,
    this.byName,
    required this.changedAt,
  });
  final int id;
  final String tableName;
  final String? recordId;
  final String action;
  final List<String>? changedFields;
  final String? byName;
  final DateTime changedAt;

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    id: j['id'],
    tableName: j['table_name'],
    recordId: j['record_id'],
    action: j['action'],
    changedFields: (j['changed_fields'] as List?)?.cast<String>(),
    byName: (j['team_members'] as Map?)?['full_name'],
    changedAt: DateTime.parse(j['changed_at']),
  );
}
