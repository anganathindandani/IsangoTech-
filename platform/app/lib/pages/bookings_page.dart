import 'package:flutter/material.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../widgets/ui.dart';

/// The coming two weeks of bookings, by day. Staff see only their own.
class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  Key _key = UniqueKey();

  /// The first business date shown.
  DateTime _start = businessToday();
  bool _showCancelled = false;

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context);
    return PageBody(
      maxWidth: 900,
      children: [
        PageHeader(
          'Bookings',
          subtitle: '${dayOf(_start)} to ${dayOf(_start.add(const Duration(days: 13)))}',
          actions: [
            IconButton(
              tooltip: 'Earlier',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _start = _start.subtract(const Duration(days: 14))),
            ),
            OutlinedButton(onPressed: () => setState(() => _start = businessToday()), child: const Text('Today')),
            IconButton(
              tooltip: 'Later',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _start = _start.add(const Duration(days: 14))),
            ),
            FilterChip(
              label: const Text('Show cancelled'),
              selected: _showCancelled,
              onSelected: (v) => setState(() => _showCancelled = v),
            ),
          ],
        ),
        Loader<List<Booking>>(
          key: ValueKey('${me.businessId}$_start$_key'),
          placeholder: const Card(child: SkeletonList()),
          load: () => repo.bookings(
            me.businessId,
            businessDayStart(_start),
            businessDayStart(_start.add(const Duration(days: 14))),
          ),
          builder: (context, all, _) {
            final list = [
              for (final b in all)
                if (_showCancelled || b.status != 'cancelled') b,
            ];
            if (list.isEmpty) return const Card(child: EmptyState('No bookings in these two weeks.'));
            final byDay = <String, List<Booking>>{};
            for (final b in list) {
              byDay.putIfAbsent(day(b.startsAt), () => []).add(b);
            }
            return Column(
              children: [
                for (final e in byDay.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Section(
                      title: e.key,
                      child: Column(
                        children: [
                          for (final b in e.value)
                            BookingTile(booking: b, onChanged: () => setState(() => _key = UniqueKey())),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// One booking with a menu to mark it completed, a no-show or cancelled.
class BookingTile extends StatelessWidget {
  const BookingTile({super.key, required this.booking, required this.onChanged});
  final Booking booking;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final details = [
      b.service,
      if (b.staff != null) 'with ${b.staff}',
      if (b.source != null) bookingSources[b.source],
    ].whereType<String>().join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox(
        width: 56,
        child: Text(time(b.startsAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      title: Text(b.customer),
      subtitle: Text(
        [
          details,
          if (b.depositStatus == 'requested')
            'Deposit of ${money(b.depositAmount)} due'
                '${b.depositDueBy == null ? '' : ' by ${dateTime(b.depositDueBy)}'}'
                ' · ref ${b.depositReference}',
          if (b.depositStatus == 'paid') 'Deposit of ${money(b.depositAmount)} paid',
          if (b.depositStatus == 'waived') 'Deposit waived',
          if (b.notes.isNotEmpty) b.notes,
        ].where((s) => s.isNotEmpty).join('\n'),
      ),
      isThreeLine: b.depositStatus == 'requested' || b.notes.isNotEmpty,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusChip(bookingStatuses[b.status] ?? b.status, color: StatusChip.colorFor(b.status)),
          PopupMenuButton<String>(
            tooltip: 'Change',
            onSelected: (v) async {
              final (Future<void> Function() action, String done) = switch (v) {
                'deposit_paid' => (
                  () => repo.setDepositStatus(b.id, 'paid'),
                  'Deposit received. The booking is confirmed.',
                ),
                'deposit_waived' => (
                  () => repo.setDepositStatus(b.id, 'waived'),
                  'Deposit waived. The booking is confirmed.',
                ),
                _ => (() => repo.setBookingStatus(b.id, v), 'Booking updated.'),
              };
              final ok = await run(context, action, done: done);
              if (ok) onChanged();
            },
            itemBuilder: (_) => [
              for (final s in ['confirmed', 'completed', 'no_show', 'cancelled'])
                if (s != b.status) PopupMenuItem(value: s, child: Text('Mark as ${bookingStatuses[s]!.toLowerCase()}')),
              if (b.depositStatus == 'requested' && Session.of(context).isManager) ...[
                const PopupMenuItem(value: 'deposit_paid', child: Text('Deposit received')),
                const PopupMenuItem(value: 'deposit_waived', child: Text('Waive the deposit')),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
