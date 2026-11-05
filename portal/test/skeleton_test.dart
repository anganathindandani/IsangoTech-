import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isangotech_portal/app.dart';
import 'package:isangotech_portal/widgets/ui.dart';

void main() {
  testWidgets('a loading list shows skeleton rows, then the data', (tester) async {
    final done = Completer<String>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Loader<String>(load: () => done.future, builder: (_, value, _) => Text(value)),
        ),
      ),
    );
    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    done.complete('Three leads');
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonList), findsNothing);
    expect(find.text('Three leads'), findsOneWidget);
  });

  testWidgets('a failed load still offers a retry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Loader<String>(load: () async => throw StateError('nope'), builder: (_, value, _) => Text(value)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('nope'), findsOneWidget);
    expect(find.byType(SkeletonList), findsNothing);
  });

  testWidgets('detail and list skeletons fit a phone width', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DetailSkeleton(showChips: true, stacked: true, leftSections: 2, rightSections: 0)),
      ),
    );
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SkeletonList(rows: 4, leading: true, trailing: true))),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the same skeleton list can stand in for two sections', (tester) async {
    const list = SkeletonList(rows: 2, trailing: true, padding: EdgeInsets.zero);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Section(title: 'Follow-ups due', child: list),
              Section(title: 'New leads', child: list),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Follow-ups due'), findsOneWidget);
    expect(find.text('New leads'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow row keeps the title and the status', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DataTile(
            title: "Thandi's Hair Studio and Beauty Bar",
            subtitle: 'Website form · Stage 2 · Capture and respond · Follow up 5 Nov 2026',
            trailing: StatusChip('Pending approval'),
          ),
        ),
      ),
    );
    expect(find.text("Thandi's Hair Studio and Beauty Bar"), findsOneWidget);
    expect(find.text('Pending approval'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty state and filter label stay readable', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const EmptyState('No leads in this view.', icon: Icons.person_search_outlined),
              FilterBar(
                label: 'Pipeline',
                children: [ChoiceChip(label: const Text('Open'), selected: true, onSelected: (_) {})],
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('No leads in this view.'), findsOneWidget);
    expect(find.text('Pipeline'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('search submits what was typed', (tester) async {
    String? query;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchField(label: 'Search leads', hint: 'Name', onSubmitted: (value) => query = value),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'thandi');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(query, 'thandi');
  });

  testWidgets('page header stacks a long title and its actions on a phone', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PageHeader(
            "Thandi's Hair Studio and Beauty Bar",
            subtitle: 'Prospect · Salon',
            actions: [
              FilledButton(onPressed: () {}, child: const Text('Create quote')),
              OutlinedButton(onPressed: () {}, child: const Text('Open client')),
            ],
          ),
        ),
      ),
    );
    expect(find.text("Thandi's Hair Studio and Beauty Bar"), findsOneWidget);
    expect(find.text('Prospect · Salon'), findsOneWidget);
    expect(find.text('Create quote'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
