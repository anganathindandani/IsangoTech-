import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../data/models.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'bookings_page.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  Key _key = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final me = Session.of(context);
    return Loader<TodaySummary>(
      key: ValueKey('${me.businessId}$_key'),
      load: () => repo.today(me.businessId),
      builder: (context, t, reload) => PageBody(
        children: [
          PageHeader(
            'Today',
            subtitle: day(DateTime.now()),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(() => _key = UniqueKey()),
              ),
            ],
          ),
          if (me.isManager)
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _Tile(
                  label: 'Chats waiting for you',
                  value: '${t.chatsWaiting}',
                  hint: t.chatsWaiting == 0
                      ? 'The Assistant is handling every chat'
                      : 'The Assistant handed these over',
                  highlight: t.chatsWaiting > 0,
                  onTap: () => context.go('/chats'),
                ),
                _Tile(
                  label: 'Questions to answer',
                  value: '${t.openQuestions}',
                  hint: 'Answer once, and the Assistant knows next time',
                  highlight: t.openQuestions > 0,
                  onTap: () => context.go('/questions'),
                ),
                if (t.usage != null)
                  _Tile(
                    label: 'WhatsApp conversations this month',
                    value: '${t.usage!.conversations} of ${t.usage!.allowance}',
                    hint: 'Included in your plan',
                    highlight: t.usage!.conversations >= t.usage!.allowance * 0.8,
                  ),
              ],
            ),
          Section(
            title: "Today's bookings",
            trailing: TextButton(onPressed: () => context.go('/bookings'), child: const Text('All bookings')),
            child: t.bookings.isEmpty
                ? const EmptyState('No bookings today.')
                : Column(
                    children: [
                      for (final b in t.bookings)
                        BookingTile(booking: b, onChanged: () => setState(() => _key = UniqueKey())),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.hint, this.highlight = false, this.onTap});
  final String label;
  final String value;
  final String hint;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Side by side on wider screens, full width on phones.
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return SizedBox(
      width: narrow ? double.infinity : 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: highlight ? Brand.ochre : Brand.turquoise, width: 4)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 6),
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(hint, style: const TextStyle(fontSize: 13, color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
