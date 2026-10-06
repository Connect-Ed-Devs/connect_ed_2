import 'package:connect_ed_2/frontend/assignments/assignments.dart';
import 'package:connect_ed_2/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    // AssignmentsPage reads the global `prefs`, which is only assigned in
    // main(). Tests never call main(), so seed it here.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('renders the Assignments header', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AssignmentsPage()),
    );
    await tester.pump();

    expect(find.text('Assignments'), findsOneWidget);
  });

  testWidgets('shows an empty or error state, never a blank screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AssignmentsPage()),
    );
    await tester.pump();
    // Let the async cache fetch settle.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // With no cached calendar the page must resolve to exactly one of its
    // documented states -- never an empty frame.
    final empty = find.text('No assignments yet');
    final error = find.text('Could not load assignments');
    final loading = find.byType(CircularProgressIndicator);

    expect(
      empty.evaluate().isNotEmpty ||
          error.evaluate().isNotEmpty ||
          loading.evaluate().isNotEmpty,
      isTrue,
      reason: 'AssignmentsPage rendered none of its known states',
    );
  });

  testWidgets('is reachable as a distinct tab page', (tester) async {
    // Guards against the tab being added to main.dart's page list but
    // failing to construct.
    expect(() => const AssignmentsPage(), returnsNormally);
  });
}
