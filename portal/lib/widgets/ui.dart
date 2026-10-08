import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme.dart';

/// Turns errors into the plain message the database or auth service gave.
String errorMessage(Object e) {
  if (e is PostgrestException) {
    if (e.code == '42501') return "You don't have permission to do that.";
    if (e.code == '23505') return 'That already exists.';
    if (e.code == '23P01') return 'That overlaps with an existing booking slot.';
    return e.message;
  }
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    if (m.contains('totp') || m.contains('code')) {
      return "That code didn't work. Check the code in your authenticator app and try again.";
    }
    if (m.contains('invalid login credentials')) return "That email and password don't match. Please try again.";
    return e.message;
  }
  if (e is StateError) return e.message;
  return 'Something went wrong. Please try again.';
}

void showError(BuildContext context, Object e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMessage(e)), backgroundColor: Brand.terracotta, behavior: SnackBarBehavior.floating),
  );
}

void showDone(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}

/// Runs an action, shows any error, and reports whether it worked.
Future<bool> run(BuildContext context, Future<void> Function() action, {String? done}) async {
  try {
    await action();
    if (done != null && context.mounted) showDone(context, done);
    return true;
  } catch (e) {
    if (context.mounted) showError(context, e);
    return false;
  }
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Confirm'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
      ],
    ),
  );
  return ok ?? false;
}

/// Loads data and shows a spinner, an error with a retry button, or the result.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;

  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() => _future = widget.load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(errorMessage(snap.error!), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _reload, child: const Text('Try again')),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        return widget.builder(context, snap.data as T, _reload);
      },
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color});
  final String label;
  final Color? color;

  static Color colorFor(String status) => switch (status) {
    'new' || 'draft' || 'open' || 'prospect' || 'booked' => Brand.indigo,
    'won' || 'accepted' || 'paid' || 'active' || 'completed' => Brand.turquoiseText,
    'pending_approval' || 'part_paid' || 'assessment' || 'quoted' || 'contacted' || 'sent' || 'unpaid' => Brand.ochre,
    'lost' || 'declined' || 'expired' || 'void' || 'cancelled' || 'no_show' || 'overdue' || 'past' => Brand.terracotta,
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(color: c, fontWeight: FontWeight.w500, fontSize: 12.5),
      ),
    );
  }
}

/// A titled white panel used on detail pages.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      semanticContainer: false,

      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Label above value, for detail pages.
class Field extends StatelessWidget {
  const Field(this.label, this.value, {super.key});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54)),
          const SizedBox(height: 2),
          SelectableText(value == null || value!.isEmpty ? '—' : value!),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.black54),
      ),
    ),
  );
}

/// Page body with a max width and padding, scrollable.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1100});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final c in children) Padding(padding: const EdgeInsets.only(bottom: 16), child: c)],
            ),
          ),
        ),
      ],
    );
  }
}

/// Two columns on wide screens, one on phones.
class Columns extends StatelessWidget {
  const Columns({super.key, required this.left, required this.right});
  final List<Widget> left;
  final List<Widget> right;

  @override
  Widget build(BuildContext context) {
    Widget col(List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [for (final c in items) Padding(padding: const EdgeInsets.only(bottom: 16), child: c)],
    );
    return LayoutBuilder(
      builder: (context, box) => box.maxWidth < 800
          ? col([...left, ...right])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: col(left)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: col(right)),
              ],
            ),
    );
  }
}

/// Date picker field that shows the chosen date.
Future<DateTime?> pickDate(BuildContext context, {DateTime? initial}) => showDatePicker(
  context: context,
  initialDate: initial ?? DateTime.now(),
  firstDate: DateTime(2024),
  lastDate: DateTime(2040),
);

String? requiredText(String? v) => v == null || v.trim().isEmpty ? 'Required' : null;

String? amountText(String? v) {
  if (v == null || v.trim().isEmpty) return 'Required';
  final n = num.tryParse(v.replaceAll(' ', '').replaceAll(',', '.'));
  if (n == null || n < 0) return 'Enter an amount, e.g. 4500 or 4500.50';
  return null;
}

num parseAmount(String v) => num.parse(v.replaceAll(' ', '').replaceAll(',', '.'));
