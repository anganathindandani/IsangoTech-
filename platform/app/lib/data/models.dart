import '../format.dart';

/// A business this person can sign in to, and their role in it.
class Membership {
  Membership({
    required this.businessId,
    required this.businessName,
    required this.timeZone,
    required this.role,
    required this.fullName,
  });
  final String businessId;
  final String businessName;
  final String timeZone;
  final String role;
  final String fullName;

  bool get isOwner => role == 'owner';
  bool get isManager => role == 'owner' || role == 'manager';

  factory Membership.fromJson(Map<String, dynamic> j) => Membership(
    businessId: j['business_id'] as String,
    businessName: (j['business'] as Map)['name'] as String,
    timeZone: (j['business'] as Map)['time_zone'] as String,
    role: j['role'] as String,
    fullName: j['full_name'] as String,
  );
}

class Usage {
  Usage({required this.conversations, required this.allowance, required this.costZar});
  final int conversations;
  final int allowance;
  final num costZar;
}

class TodaySummary {
  TodaySummary({required this.bookings, required this.chatsWaiting, required this.openQuestions, this.usage});
  final List<Booking> bookings;
  final int chatsWaiting;
  final int openQuestions;
  final Usage? usage;

  factory TodaySummary.fromJson(Map<String, dynamic> j) {
    final u = j['usage'] as Map<String, dynamic>?;
    return TodaySummary(
      bookings: [
        for (final b in (j['bookings_today'] as List).cast<Map<String, dynamic>>())
          Booking(
            id: b['id'] as String,
            startsAt: parseTime(b['starts_at'])!,
            endsAt: parseTime(b['ends_at'])!,
            status: b['status'] as String,
            customer: b['customer'] as String? ?? '',
            service: b['service'] as String?,
            staff: b['staff'] as String?,
          ),
      ],
      chatsWaiting: (j['chats_waiting'] as num).toInt(),
      openQuestions: (j['open_questions'] as num).toInt(),
      usage: u == null
          ? null
          : Usage(
              conversations: (u['conversations'] as num).toInt(),
              allowance: (u['allowance'] as num).toInt(),
              costZar: parseNum(u['cost_zar']) ?? 0,
            ),
    );
  }
}

class Booking {
  Booking({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.customer,
    this.customerNumber,
    this.service,
    this.staff,
    this.source,
    this.depositAmount = 0,
    this.depositStatus = 'not_required',
    this.notes = '',
  });
  final String id;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status;
  final String customer;
  final String? customerNumber;
  final String? service;
  final String? staff;
  final String? source;
  final num depositAmount;
  final String depositStatus;
  final String notes;

  factory Booking.fromJson(Map<String, dynamic> j) {
    final c = j['customer'] as Map<String, dynamic>?;
    return Booking(
      id: j['id'] as String,
      startsAt: parseTime(j['starts_at'])!,
      endsAt: parseTime(j['ends_at'])!,
      status: j['status'] as String,
      customer: (c?['full_name'] as String?) ?? (c?['whatsapp_number'] as String?) ?? '',
      customerNumber: c?['whatsapp_number'] as String?,
      service: (j['service'] as Map?)?['name'] as String?,
      staff: (j['staff'] as Map?)?['full_name'] as String?,
      source: j['source'] as String?,
      depositAmount: parseNum(j['deposit_amount']) ?? 0,
      depositStatus: j['deposit_status'] as String? ?? 'not_required',
      notes: j['notes'] as String? ?? '',
    );
  }
}

class Conversation {
  Conversation({
    required this.id,
    required this.customerName,
    required this.number,
    required this.handledBy,
    this.lastMessageAt,
    this.lastCustomerMessageAt,
  });
  final String id;
  final String? customerName;
  final String? number;
  final String handledBy;
  final DateTime? lastMessageAt;
  final DateTime? lastCustomerMessageAt;

  String get title => customerName ?? (number == null ? 'Customer' : '+$number');
  bool get withPerson => handledBy == 'person';

  /// WhatsApp lets the business reply freely for 24 hours after the customer's last message.
  bool canReply(DateTime now) =>
      lastCustomerMessageAt != null && now.difference(lastCustomerMessageAt!) < const Duration(hours: 24);

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final c = j['customer'] as Map<String, dynamic>?;
    return Conversation(
      id: j['id'] as String,
      customerName: c?['full_name'] as String?,
      number: c?['whatsapp_number'] as String?,
      handledBy: j['handled_by'] as String,
      lastMessageAt: parseTime(j['last_message_at']),
      lastCustomerMessageAt: parseTime(j['last_customer_message_at']),
    );
  }
}

class Message {
  Message({required this.id, required this.sender, required this.body, required this.createdAt});
  final String id;
  final String sender;
  final String body;
  final DateTime createdAt;

  bool get fromCustomer => sender == 'customer';

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    id: j['id'] as String,
    sender: j['sender'] as String,
    body: j['body'] as String,
    createdAt: parseTime(j['created_at'])!,
  );
}

class Question {
  Question({required this.id, required this.question, required this.createdAt, this.conversationId});
  final String id;
  final String question;
  final DateTime createdAt;
  final String? conversationId;

  factory Question.fromJson(Map<String, dynamic> j) => Question(
    id: j['id'] as String,
    question: j['question'] as String,
    createdAt: parseTime(j['created_at'])!,
    conversationId: j['conversation_id'] as String?,
  );
}

/// Opening hours: day key ("mon") to a list of [open, close] times ("08:00").
typedef Hours = Map<String, List<List<String>>>;

Hours hoursFromJson(dynamic v) => {
  for (final e in ((v as Map?) ?? {}).entries)
    e.key as String: [
      for (final span in (e.value as List)) [for (final t in (span as List)) t as String],
    ],
};

class AssistantSettings {
  AssistantSettings({
    required this.openingHours,
    required this.languages,
    required this.tone,
    required this.policies,
    required this.handoverTopics,
    required this.minBookingNoticeHours,
    required this.changeNoticeHours,
    required this.depositRequired,
    required this.depositPercent,
    required this.privacyNoticeUrl,
    required this.messageRetentionMonths,
    required this.assistantEnabled,
    this.remindersEnabled = false,
    this.reminderHoursBefore = 24,
    this.reminderTemplate,
    this.reminderTemplateLanguage = 'en',
  });
  Hours openingHours;
  List<String> languages;
  String tone;
  String policies;
  String handoverTopics;
  int minBookingNoticeHours;
  int changeNoticeHours;
  bool depositRequired;
  num depositPercent;
  String? privacyNoticeUrl;
  int messageRetentionMonths;
  bool assistantEnabled;
  bool remindersEnabled;
  int reminderHoursBefore;

  /// The name of the reminder template Meta approved for this business.
  String? reminderTemplate;
  String reminderTemplateLanguage;

  factory AssistantSettings.fromJson(Map<String, dynamic> j) => AssistantSettings(
    openingHours: hoursFromJson(j['opening_hours']),
    languages: (j['languages'] as List).cast<String>(),
    tone: j['tone'] as String,
    policies: j['policies'] as String,
    handoverTopics: j['handover_topics'] as String,
    minBookingNoticeHours: (j['min_booking_notice_hours'] as num).toInt(),
    changeNoticeHours: (j['change_notice_hours'] as num).toInt(),
    depositRequired: j['deposit_required'] as bool,
    depositPercent: parseNum(j['deposit_percent']) ?? 0,
    privacyNoticeUrl: j['privacy_notice_url'] as String?,
    messageRetentionMonths: (j['message_retention_months'] as num).toInt(),
    assistantEnabled: j['assistant_enabled'] as bool,
    remindersEnabled: j['reminders_enabled'] as bool? ?? false,
    reminderHoursBefore: (j['reminder_hours_before'] as num?)?.toInt() ?? 24,
    reminderTemplate: j['reminder_template'] as String?,
    reminderTemplateLanguage: j['reminder_template_language'] as String? ?? 'en',
  );

  Map<String, dynamic> toJson() => {
    'opening_hours': openingHours,
    'languages': languages,
    'tone': tone,
    'policies': policies,
    'handover_topics': handoverTopics,
    'min_booking_notice_hours': minBookingNoticeHours,
    'change_notice_hours': changeNoticeHours,
    'deposit_required': depositRequired,
    'deposit_percent': depositPercent,
    'privacy_notice_url': (privacyNoticeUrl ?? '').trim().isEmpty ? null : privacyNoticeUrl!.trim(),
    'message_retention_months': messageRetentionMonths,
    'assistant_enabled': assistantEnabled,
    'reminders_enabled': remindersEnabled,
    'reminder_hours_before': reminderHoursBefore,
    'reminder_template': (reminderTemplate ?? '').trim().isEmpty ? null : reminderTemplate!.trim(),
    'reminder_template_language': reminderTemplateLanguage.trim(),
  };
}

class Service {
  Service({
    this.id,
    required this.name,
    this.description = '',
    this.price,
    this.priceFrom = false,
    this.durationMinutes,
    this.active = true,
  });
  final String? id;
  String name;
  String description;
  num? price;
  bool priceFrom;
  int? durationMinutes;
  bool active;

  String get priceLabel => price == null ? 'Price on request' : '${priceFrom ? 'from ' : ''}${money(price)}';

  factory Service.fromJson(Map<String, dynamic> j) => Service(
    id: j['id'] as String,
    name: j['name'] as String,
    description: j['description'] as String? ?? '',
    price: parseNum(j['price']),
    priceFrom: j['price_from'] as bool? ?? false,
    durationMinutes: (j['duration_minutes'] as num?)?.toInt(),
    active: j['active'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'description': description.trim(),
    'price': price,
    'price_from': priceFrom,
    'duration_minutes': durationMinutes,
    'active': active,
  };
}

class StaffMember {
  StaffMember({this.id, required this.fullName, this.active = true, this.hasLogin = false});
  final String? id;
  String fullName;
  bool active;

  /// Linked to someone's login, so they see their own bookings.
  final bool hasLogin;

  factory StaffMember.fromJson(Map<String, dynamic> j) => StaffMember(
    id: j['id'] as String,
    fullName: j['full_name'] as String,
    active: j['active'] as bool,
    hasLogin: j['user_id'] != null,
  );
}

class KnowledgeItem {
  KnowledgeItem({this.id, required this.question, required this.answer, this.active = true});
  final String? id;
  String question;
  String answer;
  bool active;

  factory KnowledgeItem.fromJson(Map<String, dynamic> j) => KnowledgeItem(
    id: j['id'] as String,
    question: j['question'] as String,
    answer: j['answer'] as String,
    active: j['active'] as bool,
  );
}

/// A business as IsangoTech's admins see it: plan details and owners, no customer data.
class AdminBusiness {
  AdminBusiness({
    required this.id,
    required this.name,
    required this.industry,
    required this.status,
    required this.products,
    required this.allowance,
    required this.assistantEnabled,
    required this.owners,
    this.whatsappPhoneNumberId,
    this.whatsappDisplayNumber,
  });
  final String id;
  String name;
  String industry;
  String status;
  List<String> products;
  int allowance;
  final bool assistantEnabled;
  final List<({String name, String email})> owners;
  String? whatsappPhoneNumberId;
  String? whatsappDisplayNumber;

  factory AdminBusiness.fromJson(Map<String, dynamic> j) => AdminBusiness(
    id: j['id'] as String,
    name: j['name'] as String,
    industry: j['industry'] as String,
    status: j['status'] as String,
    products: (j['products'] as List).cast<String>(),
    allowance: (j['monthly_conversation_allowance'] as num).toInt(),
    assistantEnabled: j['assistant_enabled'] as bool,
    whatsappPhoneNumberId: j['whatsapp_phone_number_id'] as String?,
    whatsappDisplayNumber: j['whatsapp_display_number'] as String?,
    owners: [
      for (final o in (j['owners'] as List).cast<Map<String, dynamic>>())
        (name: o['name'] as String, email: o['email'] as String? ?? ''),
    ],
  );

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'industry': industry,
    'status': status,
    'products': products,
    'monthly_conversation_allowance': allowance,
    'whatsapp_phone_number_id': (whatsappPhoneNumberId ?? '').trim(),
    'whatsapp_display_number': (whatsappDisplayNumber ?? '').trim(),
  };
}

/// Someone who signs in to this business.
class TeamMember {
  TeamMember({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.active,
    required this.signedIn,
    this.staffName,
  });
  final String userId;
  final String fullName;
  final String email;
  final String role;
  final bool active;

  /// Whether they've ever signed in (if not, they may still need their setup link).
  final bool signedIn;
  final String? staffName;

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
    userId: j['user_id'] as String,
    fullName: j['full_name'] as String,
    email: j['email'] as String? ?? '',
    role: j['role'] as String,
    active: j['active'] as bool,
    signedIn: j['signed_in'] as bool,
    staffName: j['staff_name'] as String?,
  );
}
