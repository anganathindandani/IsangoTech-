import 'package:flutter_test/flutter_test.dart';
import 'package:isangotech_business/data/models.dart';
import 'package:isangotech_business/format.dart';

void main() {
  test('rand are written the way the website writes them', () {
    expect(money(450), 'R450');
    expect(money(4500), 'R4 500');
    expect(money(36.5), 'R36.50');
    expect(money(null), 'R0');
  });

  test('times show in South African time whatever the device is set to', () {
    setBusinessTimeZone('Africa/Johannesburg');
    final twelveUtc = DateTime.utc(2026, 10, 17, 12, 0);
    expect(time(twelveUtc), '14:00');
    expect(day(DateTime.utc(2026, 10, 17, 23, 30)), 'Sunday 18 October', reason: '01:30 the next day in SA');
    expect(businessDayStart(DateTime.utc(2026, 10, 17)), DateTime.utc(2026, 10, 16, 22));
  });

  test('chat times: minutes, then the time today, then the date', () {
    final now = DateTime.utc(2026, 10, 17, 12, 0);
    expect(ago(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
    expect(ago(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
    expect(ago(now.subtract(const Duration(hours: 3)), now: now), '11:00');
    expect(ago(now.subtract(const Duration(days: 2)), now: now), 'Thu 15 Oct, 14:00');
  });

  test('a chat can be replied to for 24 hours after the customer last wrote', () {
    final now = DateTime.utc(2026, 10, 17, 12);
    Conversation chat(Duration since) => Conversation(
      id: 'c',
      customerName: null,
      number: '27825550001',
      handledBy: 'person',
      lastCustomerMessageAt: now.subtract(since),
    );
    expect(chat(const Duration(hours: 23)).canReply(now), isTrue);
    expect(chat(const Duration(hours: 25)).canReply(now), isFalse);
    expect(chat(Duration.zero).title, '+27825550001', reason: 'no name: show the number');
  });

  test('settings round-trip, and an empty privacy link is saved as none', () {
    final s = AssistantSettings.fromJson({
      'opening_hours': {
        'sat': [
          ['07:00', '15:00'],
        ],
      },
      'languages': ['en', 'xh'],
      'tone': 'Warm',
      'policies': '',
      'handover_topics': '',
      'min_booking_notice_hours': 2,
      'change_notice_hours': 24,
      'deposit_required': true,
      'deposit_percent': '20.00',
      'privacy_notice_url': null,
      'message_retention_months': 12,
      'assistant_enabled': true,
    });
    s.privacyNoticeUrl = '   ';
    final j = s.toJson();
    expect(j['opening_hours'], {
      'sat': [
        ['07:00', '15:00'],
      ],
    });
    expect(j['deposit_percent'], 20);
    expect(j['privacy_notice_url'], isNull);
    expect(j['reminders_enabled'], isFalse, reason: 'reminders default to off');
    s.reminderTemplate = '  ';
    expect(s.toJson()['reminder_template'], isNull, reason: 'an empty template name is saved as none');
    expect(j['deposit_hold_hours'], 24, reason: 'an unpaid booking is held a day by default');
    expect(j['deposit_payment_link'], isNull);
    s.depositPaymentLink = ' https://pay.yoco.com/salon ';
    s.depositPaymentInstructions = ' EFT to FNB 620000 ';
    expect(s.toJson()['deposit_payment_link'], 'https://pay.yoco.com/salon');
    expect(s.toJson()['deposit_payment_instructions'], 'EFT to FNB 620000');
  });

  test('the deposit reference matches what the Assistant gives the customer', () {
    final b = Booking.fromJson({
      'id': 'ea371613-d71b-4509-9401-af6f5caf21c4',
      'starts_at': '2026-10-24T08:00:00+00:00',
      'ends_at': '2026-10-24T10:00:00+00:00',
      'status': 'pending',
      'deposit_amount': '90.00',
      'deposit_status': 'requested',
      'deposit_due_by': '2026-10-23T08:00:00+00:00',
    });
    expect(b.depositReference, 'EA3716');
    expect(dateTime(b.depositDueBy), 'Fri 23 Oct, 10:00', reason: 'shown in business time');
  });
}
