import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isangotech_business/widgets/ui.dart';

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

    done.complete('Three bookings');
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonList), findsNothing);
    expect(find.text('Three bookings'), findsOneWidget);
  });
}
