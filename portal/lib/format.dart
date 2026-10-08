import 'package:intl/intl.dart';

final _money = NumberFormat.currency(locale: 'en_ZA', symbol: 'R ', decimalDigits: 2);
final _date = DateFormat('d MMM yyyy');
final _dateTime = DateFormat('EEE d MMM yyyy, HH:mm');

String money(num? value) => _money.format(value ?? 0);
String date(DateTime? d) => d == null ? '—' : _date.format(d.toLocal());
String dateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d.toLocal());

/// yyyy-MM-dd for Postgres date columns.
String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime? parseDate(dynamic v) => v == null ? null : DateTime.parse(v as String);
num parseNum(dynamic v) => v == null ? 0 : (v is num ? v : num.parse(v.toString()));

const growthStages = {1: 'Get found', 2: 'Capture and respond', 3: 'Run operations', 4: 'Automate'};

String stageLabel(int? stage) => stage == null ? 'Not sure yet' : 'Stage $stage · ${growthStages[stage]}';

const pipelineStages = {
  'new': 'New',
  'contacted': 'Contacted',
  'assessment': 'Assessment',
  'quoted': 'Quoted',
  'won': 'Won',
  'lost': 'Lost',
};

const leadSources = {
  'website_form': 'Website form',
  'whatsapp': 'WhatsApp',
  'walk_in': 'Walk-in',
  'phone': 'Phone call',
  'referral': 'Referral',
  'other': 'Other',
};

const clientStatuses = {'prospect': 'Prospect', 'active': 'Active', 'lost': 'Lost', 'past': 'Past'};

const quoteStatuses = {
  'draft': 'Draft',
  'pending_approval': 'Pending approval',
  'sent': 'Sent',
  'accepted': 'Accepted',
  'declined': 'Declined',
  'expired': 'Expired',
};

const paymentStatuses = {
  'draft': 'Draft',
  'unpaid': 'Unpaid',
  'part_paid': 'Part paid',
  'paid': 'Paid',
  'void': 'Void',
};

const invoiceTypes = {'setup': 'Setup', 'monthly': 'Monthly', 'custom': 'Custom'};
const paymentMethods = {'eft': 'EFT', 'card': 'Card', 'cash': 'Cash', 'payment_link': 'Payment link', 'other': 'Other'};
const activityTypes = {'call': 'Call', 'message': 'Message', 'meeting': 'Meeting', 'note': 'Note'};
const assessmentStatuses = {
  'booked': 'Booked',
  'completed': 'Completed',
  'cancelled': 'Cancelled',
  'no_show': 'No-show',
};
const consentPurposes = {'enquiry': 'Respond to enquiry', 'whatsapp': 'WhatsApp messages', 'marketing': 'Marketing'};
const billingLabels = {'once_off': 'Once-off', 'monthly': 'Monthly'};
const consentSources = {'form': 'website form', 'whatsapp': 'WhatsApp', 'in_person': 'in person'};
