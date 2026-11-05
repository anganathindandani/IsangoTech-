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

/// A grey block standing in for content that is still loading.
///
/// Static, with no shimmer, so it stays quiet when motion is reduced. The
/// colour is the portal indigo at low opacity, which reads as a warm grey on
/// the sand background.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 6});
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final max = constraints.maxWidth;
        final boxWidth = width == null ? null : (!max.isFinite || width! <= max ? width : max);
        return Container(
          width: boxWidth,
          height: height,
          decoration: BoxDecoration(
            color: Brand.indigo.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(radius),
          ),
        );
      },
    );
  }
}

/// Rows shaped like a list, so the card keeps its place while data loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.rows = 4,
    this.leading = false,
    this.trailing = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final int rows;

  /// A small icon-sized block at the start of each row.
  final bool leading;

  /// A status-pill sized block at the end of each row.
  final bool trailing;

  final EdgeInsetsGeometry padding;

  static const _titles = [180.0, 140.0, 210.0, 160.0];
  static const _lines = [240.0, 190.0, 260.0, 150.0];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final text = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: _titles[i % 4]),
                      const SizedBox(height: 8),
                      SkeletonBox(width: _lines[i % 4], height: 12),
                    ],
                  );
                  const chip = SkeletonBox(width: 72, height: 22, radius: 999);
                  final stack = trailing && constraints.maxWidth < 520;
                  return Row(
                    crossAxisAlignment: stack ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                    children: [
                      if (leading) ...[const SkeletonBox(width: 24, height: 24, radius: 6), const SizedBox(width: 16)],
                      Expanded(
                        child: stack
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [text, const SizedBox(height: 8), chip],
                              )
                            : text,
                      ),
                      if (trailing && !stack) ...[const SizedBox(width: 16), chip],
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Header plus section cards, for a record page whose title comes from the server.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({
    super.key,
    this.leftSections = 2,
    this.rightSections = 2,
    this.maxWidth = 1100,
    this.stacked = false,
    this.showChips = false,
    this.rows = 2,
  });

  final int leftSections;
  final int rightSections;
  final double maxWidth;

  /// One column, for pages that are not split (a quote, for example).
  final bool stacked;

  /// A status pill and a short line under the title.
  final bool showChips;
  final int rows;

  Widget _section() => Card(
    semanticContainer: false,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 148, height: 18),
          const SizedBox(height: 16),
          SkeletonList(rows: rows, trailing: true, padding: EdgeInsets.zero),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    const header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SkeletonBox(width: 240, height: 28, radius: 8),
        SizedBox(height: 8),
        SkeletonBox(width: 180, height: 14),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [SkeletonBox(width: 132, height: 36, radius: 18), SkeletonBox(width: 112, height: 36, radius: 18)],
        ),
      ],
    );
    const chips = Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [SkeletonBox(width: 96, height: 24, radius: 999), SkeletonBox(width: 140, height: 14)],
    );
    final left = [for (var i = 0; i < leftSections; i++) _section()];
    final right = [for (var i = 0; i < rightSections; i++) _section()];
    return PageBody(
      maxWidth: maxWidth,
      children: [
        header,
        if (showChips) chips,
        if (stacked)
          for (final section in [...left, ...right]) section
        else
          Columns(left: left, right: right),
      ],
    );
  }
}

/// Loads data and shows a skeleton (or the given placeholder), an error with a retry button, or the result.
class Loader<T> extends StatefulWidget {
  const Loader({super.key, required this.load, required this.builder, this.placeholder = const SkeletonList()});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;

  /// What shows while [load] is in flight. List screens use [SkeletonList]; record screens use [DetailSkeleton].
  final Widget placeholder;

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
        if (!snap.hasData) {
          return Semantics(
            label: 'Loading',
            child: ExcludeSemantics(child: widget.placeholder),
          );
        }
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54)),
          const SizedBox(height: 4),
          SelectableText(value == null || value!.isEmpty ? '—' : value!),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon});
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 28, color: Brand.indigo.withValues(alpha: 0.45)),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, height: 1.4),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A short label above a wrapping row of filter chips.
class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.label, required this.children});
  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: children),
      ],
    );
  }
}

/// Search box with a label that stays visible. Runs [onSubmitted] when the person presses search.
class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.label, required this.hint, required this.onSubmitted});
  final String label;
  final String hint;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(prefixIcon: const Icon(Icons.search), labelText: label, hintText: hint),
      onSubmitted: onSubmitted,
    );
  }
}

/// List row that keeps its status on a second line when the row is narrow.
class DataTile extends StatelessWidget {
  const DataTile({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.titleStyle,
    this.trailing,
    this.leading,
    this.onTap,
    this.dense = false,
    this.contentPadding,
  });

  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final TextStyle? titleStyle;
  final Widget? trailing;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool dense;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final subtitleText = subtitle?.trim();
    final subtitleWidget = subtitleText == null || subtitleText.isEmpty
        ? null
        : Text(subtitleText, style: subtitleColor == null ? null : TextStyle(color: subtitleColor));
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = trailing != null && constraints.maxWidth.isFinite && constraints.maxWidth < 520;
        if (!stack) {
          return ListTile(
            dense: dense,
            contentPadding: contentPadding,
            leading: leading,
            title: Text(title, style: titleStyle),
            subtitle: subtitleWidget,
            trailing: trailing,
            onTap: onTap,
          );
        }
        final pad = contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
        final theme = Theme.of(context);
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: pad,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: IconTheme.merge(
                      data: IconThemeData(color: theme.colorScheme.onSurfaceVariant, size: dense ? 20 : 24),
                      child: leading!,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: titleStyle ?? theme.textTheme.bodyLarge),
                      if (subtitleWidget != null) ...[
                        const SizedBox(height: 2),
                        DefaultTextStyle(
                          style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(color: Colors.black54),
                          child: subtitleWidget,
                        ),
                      ],
                      const SizedBox(height: 8),
                      trailing!,
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Page body with a max width and padding, scrollable.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children, this.maxWidth = 1100});
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
