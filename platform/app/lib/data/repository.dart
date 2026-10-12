import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Every database call the app makes. Row-level security decides what each
/// person can see and change; the app has no permission logic of its own.
class Repository {
  Repository(this.db);
  final SupabaseClient db;

  String get _me => db.auth.currentUser!.id;

  Future<List<Membership>> memberships() async {
    final rows = await db
        .from('business_members')
        .select('business_id, role, full_name, business:businesses(name, time_zone)')
        .eq('user_id', _me)
        .eq('active', true)
        .order('created_at', ascending: true);
    return [for (final r in rows) Membership.fromJson(r)];
  }

  Future<TodaySummary> today(String businessId) async =>
      TodaySummary.fromJson(await db.rpc('today_summary', params: {'p_business': businessId}) as Map<String, dynamic>);

  // Chats ------------------------------------------------------------------

  static const _conversationColumns =
      'id, handled_by, last_message_at, last_customer_message_at, customer:customers(full_name, whatsapp_number)';

  Future<List<Conversation>> conversations(String businessId, {bool waitingOnly = false}) async {
    var q = db.from('conversations').select(_conversationColumns).eq('business_id', businessId);
    if (waitingOnly) q = q.eq('handled_by', 'person');
    final rows = await q.order('last_message_at', ascending: false, nullsFirst: false).limit(200);
    return [for (final r in rows) Conversation.fromJson(r)];
  }

  Future<Conversation> conversation(String id) async =>
      Conversation.fromJson(await db.from('conversations').select(_conversationColumns).eq('id', id).single());

  /// The latest 200 messages, oldest first.
  Future<List<Message>> messages(String conversationId) async {
    final rows = await db
        .from('messages')
        .select('id, sender, body, created_at')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(200);
    return [for (final r in rows.reversed) Message.fromJson(r)];
  }

  /// 'person' takes the chat over (the Assistant stays quiet); 'assistant' hands it back.
  Future<void> setHandledBy(String conversationId, String handledBy) =>
      db.from('conversations').update({'handled_by': handledBy}).eq('id', conversationId);

  /// Sends a WhatsApp message from the business, as the signed-in person.
  Future<void> reply(String conversationId, String body) =>
      db.functions.invoke('send-message', body: {'conversation_id': conversationId, 'body': body});

  // Questions --------------------------------------------------------------

  Future<List<Question>> openQuestions(String businessId) async {
    final rows = await db
        .from('unanswered_questions')
        .select('id, question, created_at, conversation_id')
        .eq('business_id', businessId)
        .eq('status', 'open')
        .order('created_at', ascending: false);
    return [for (final r in rows) Question.fromJson(r)];
  }

  Future<void> answerQuestion(String questionId, String answer) =>
      db.rpc('answer_question', params: {'p_question': questionId, 'p_answer': answer});

  Future<void> dismissQuestion(String questionId) =>
      db.from('unanswered_questions').update({'status': 'dismissed'}).eq('id', questionId);

  // Bookings ---------------------------------------------------------------

  /// Bookings starting between two instants, earliest first.
  Future<List<Booking>> bookings(String businessId, DateTime from, DateTime to) async {
    final rows = await db
        .from('bookings')
        .select(
          'id, starts_at, ends_at, status, source, deposit_amount, deposit_status, notes, '
          'customer:customers(full_name, whatsapp_number), service:services(name), staff:staff(full_name)',
        )
        .eq('business_id', businessId)
        .gte('starts_at', from.toUtc().toIso8601String())
        .lt('starts_at', to.toUtc().toIso8601String())
        .order('starts_at', ascending: true);
    return [for (final r in rows) Booking.fromJson(r)];
  }

  Future<void> setBookingStatus(String bookingId, String status) =>
      db.from('bookings').update({'status': status}).eq('id', bookingId);

  Future<void> setDepositStatus(String bookingId, String status) =>
      db.from('bookings').update({'deposit_status': status}).eq('id', bookingId);

  // Assistant settings -----------------------------------------------------

  Future<AssistantSettings> settings(String businessId) async =>
      AssistantSettings.fromJson(await db.from('business_settings').select().eq('business_id', businessId).single());

  Future<void> saveSettings(String businessId, AssistantSettings s) =>
      db.from('business_settings').update(s.toJson()).eq('business_id', businessId);

  Future<List<Service>> services(String businessId) async {
    final rows = await db.from('services').select().eq('business_id', businessId).order('name', ascending: true);
    return [for (final r in rows) Service.fromJson(r)];
  }

  Future<void> saveService(String businessId, Service s) => s.id == null
      ? db.from('services').insert({...s.toJson(), 'business_id': businessId})
      : db.from('services').update(s.toJson()).eq('id', s.id!);

  Future<List<StaffMember>> staff(String businessId) async {
    final rows = await db
        .from('staff')
        .select('id, full_name, active')
        .eq('business_id', businessId)
        .order('full_name', ascending: true);
    return [for (final r in rows) StaffMember.fromJson(r)];
  }

  Future<void> saveStaff(String businessId, StaffMember m) => m.id == null
      ? db.from('staff').insert({'business_id': businessId, 'full_name': m.fullName.trim(), 'active': m.active})
      : db.from('staff').update({'full_name': m.fullName.trim(), 'active': m.active}).eq('id', m.id!);

  Future<List<KnowledgeItem>> knowledge(String businessId) async {
    final rows = await db
        .from('knowledge_items')
        .select()
        .eq('business_id', businessId)
        .order('question', ascending: true);
    return [for (final r in rows) KnowledgeItem.fromJson(r)];
  }

  Future<void> saveKnowledge(String businessId, KnowledgeItem k) {
    final values = {'question': k.question.trim(), 'answer': k.answer.trim(), 'active': k.active};
    return k.id == null
        ? db.from('knowledge_items').insert({...values, 'business_id': businessId})
        : db.from('knowledge_items').update(values).eq('id', k.id!);
  }

  Future<void> deleteKnowledge(String id) => db.from('knowledge_items').delete().eq('id', id);

  // IsangoTech admins ----------------------------------------------------------

  Future<bool> isPlatformAdmin() async => await db.rpc('is_platform_admin') == true;

  Future<List<AdminBusiness>> adminBusinesses() async {
    final rows = (await db.rpc('admin_businesses') as List).cast<Map<String, dynamic>>();
    return [for (final r in rows) AdminBusiness.fromJson(r)];
  }

  Future<void> adminUpdateBusiness(AdminBusiness b) =>
      db.rpc('admin_update_business', params: {'p_business': b.id, 'p_values': b.toJson()});

  /// Creates the business, its owner's login and membership; returns the owner's setup link.
  Future<({String setupLink, bool newLogin})> onboard(AdminBusiness b, String ownerName, String ownerEmail) async {
    final res = await db.functions.invoke(
      'onboard-business',
      body: {
        'business': b.toJson(),
        'owner': {'full_name': ownerName, 'email': ownerEmail},
      },
    );
    final data = res.data as Map<String, dynamic>;
    return (setupLink: data['setup_link'] as String, newLogin: data['new_login'] as bool);
  }

  /// A fresh one-time link for someone to choose a new password.
  Future<String> setupLink(String email) async {
    final res = await db.functions.invoke('onboard-business', body: {'action': 'link', 'email': email});
    return (res.data as Map<String, dynamic>)['setup_link'] as String;
  }

  Future<void> setPassword(String password) => db.auth.updateUser(UserAttributes(password: password));

  // Team (owners) --------------------------------------------------------------

  Future<List<TeamMember>> team(String businessId) async {
    final rows = (await db.rpc('team_members', params: {'p_business': businessId}) as List)
        .cast<Map<String, dynamic>>();
    return [for (final r in rows) TeamMember.fromJson(r)];
  }

  /// Adds a manager or staff member; returns their setup link, or null if they already have their own login.
  Future<({String? setupLink, bool newLogin})> addTeamMember(
    String businessId, {
    required String fullName,
    required String email,
    required String role,
    String? staffId,
  }) async {
    final res = await db.functions.invoke(
      'team-member',
      body: {'business_id': businessId, 'full_name': fullName, 'email': email, 'role': role, 'staff_id': staffId},
    );
    final data = res.data as Map<String, dynamic>;
    return (setupLink: data['setup_link'] as String?, newLogin: data['new_login'] as bool);
  }

  Future<String> teamSetupLink(String businessId, String email) async {
    final res = await db.functions.invoke(
      'team-member',
      body: {'action': 'link', 'business_id': businessId, 'email': email},
    );
    return (res.data as Map<String, dynamic>)['setup_link'] as String;
  }

  Future<void> updateTeamMember(String businessId, String userId, {String? role, bool? active}) => db
      .from('business_members')
      .update({'role': ?role, 'active': ?active})
      .eq('business_id', businessId)
      .eq('user_id', userId);
}
