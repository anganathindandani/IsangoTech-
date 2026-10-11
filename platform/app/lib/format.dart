import 'package:intl/intl.dart';

final _time = DateFormat('HH:mm');
final _day = DateFormat('EEEE d MMMM');
final _dateTime = DateFormat('EEE d MMM, HH:mm');
final _thousands = NumberFormat('#,##0', 'en_US');

/// Rand the way the website writes them: R450, R4 500, R36.50.
String money(num? value) {
  final v = value ?? 0;
  final whole = _thousands.format(v.truncate()).replaceAll(',', '\u00a0');
  final cents = ((v - v.truncate()).abs() * 100).round();
  return cents == 0 ? 'R$whole' : 'R$whole.${cents.toString().padLeft(2, '0')}';
}

// Times show in the business's own time, whatever the device is set to.
// Client businesses are in South Africa, which is UTC+2 all year (no
// daylight saving), so a fixed offset per time zone is enough.
const _offsets = {'Africa/Johannesburg': Duration(hours: 2)};
Duration _offset = const Duration(hours: 2);

void setBusinessTimeZone(String timeZone) => _offset = _offsets[timeZone] ?? const Duration(hours: 2);

/// An instant as the business's wall-clock time (in a UTC DateTime, so nothing converts it again).
DateTime businessTime(DateTime instant) => instant.toUtc().add(_offset);

/// Today's date at the business.
DateTime businessToday() {
  final t = businessTime(DateTime.now());
  return DateTime.utc(t.year, t.month, t.day);
}

/// The instant a business day starts, for database queries.
DateTime businessDayStart(DateTime businessDate) =>
    DateTime.utc(businessDate.year, businessDate.month, businessDate.day).subtract(_offset);

String time(DateTime instant) => _time.format(businessTime(instant));
String day(DateTime instant) => _day.format(businessTime(instant));
String dateTime(DateTime? instant) => instant == null ? '—' : _dateTime.format(businessTime(instant));

/// A business date (from [businessToday]) as "Tuesday 14 October".
String dayOf(DateTime businessDate) => _day.format(businessDate);

/// "2 min ago", "13:05", "Tue 14 Oct, 09:30": how chat lists show times.
String ago(DateTime? d, {DateTime? now}) {
  if (d == null) return '';
  final n = now ?? DateTime.now();
  final diff = n.difference(d);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  final t = businessTime(d), today = businessTime(n);
  if (t.year == today.year && t.month == today.month && t.day == today.day) return time(d);
  return dateTime(d);
}

DateTime? parseTime(dynamic v) => v == null ? null : DateTime.parse(v as String);
num? parseNum(dynamic v) => v == null ? null : (v is num ? v : num.parse(v.toString()));

const bookingStatuses = {
  'pending': 'Pending',
  'confirmed': 'Confirmed',
  'completed': 'Completed',
  'no_show': 'No-show',
  'cancelled': 'Cancelled',
};

const bookingSources = {'whatsapp': 'WhatsApp', 'portal': 'Dashboard', 'walk_in': 'Walk-in'};

const roles = {'owner': 'Owner', 'manager': 'Manager', 'staff': 'Staff'};

const languages = {'en': 'English', 'xh': 'isiXhosa', 'af': 'Afrikaans', 'zu': 'isiZulu'};

const weekdays = [
  ('mon', 'Monday'),
  ('tue', 'Tuesday'),
  ('wed', 'Wednesday'),
  ('thu', 'Thursday'),
  ('fri', 'Friday'),
  ('sat', 'Saturday'),
  ('sun', 'Sunday'),
];
