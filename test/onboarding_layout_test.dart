// A student who raised the system text size and then opened the app for the
// first time reported seeing "just the homepage" with none of its utility and
// no way forward. The welcome screen was a fixed `Column` — a header sized to
// 42% of the viewport, then an `Expanded` area holding the title, the tagline
// and the Get Started button. Nothing about that area could scroll, so once the
// title wrapped to three lines the button was pushed past the bottom edge of
// the screen: the first-run flow dead-ended and the app looked broken.
//
// These tests pin the two properties that make it usable at any text size: no
// RenderFlex overflow, and the button can actually be brought on screen. They
// run at a small-but-real iPhone SE viewport with 2x and 3x text, which is the
// range accessibility settings reach.
//
// TypewriterText (used on both screens) loops forever on Future.delayed, so
// `pumpAndSettle` would never return and the pending delay has to be drained
// before the test ends — hence _unmount at the bottom of each case.
import 'package:connect_ed_2/frontend/onboarding/finish_onboarding.dart';
import 'package:connect_ed_2/frontend/onboarding/welcome.dart';
import 'package:connect_ed_2/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// iPhone SE — the smallest viewport still in wide use.
const Size _se = Size(375, 667);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  for (final scale in <double>[2.0, 3.0]) {
    testWidgets('welcome screen keeps Get Started reachable at ${scale}x text', (
      tester,
    ) async {
      _useDeviceAndTextScale(tester, _se, scale);

      await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
      // No pumpAndSettle: the gradient animation repeats forever.
      await tester.pump();

      // The reported bug arrives through the exception channel as an overflow.
      expect(
        tester.takeException(),
        isNull,
        reason: 'the welcome screen overflowed its ${_se.height}px height',
      );

      // The screen has to scroll, otherwise there is no way to the button.
      expect(
        find.byType(Scrollable),
        findsWidgets,
        reason: 'the welcome screen must scroll when the text does not fit',
      );

      // Present in the tree is not the same as reachable: bring it on screen
      // and check it really lands inside the viewport.
      await tester.ensureVisible(find.text('Get Started'));
      await tester.pump();

      final button = tester.getRect(find.text('Get Started'));
      expect(button.top, greaterThanOrEqualTo(0.0));
      expect(
        button.bottom,
        lessThanOrEqualTo(_se.height),
        reason: 'Get Started sits below the bottom edge of the screen',
      );
      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });

    testWidgets('finish setup keeps Let\'s Go reachable at ${scale}x text', (
      tester,
    ) async {
      _useDeviceAndTextScale(tester, _se, scale);

      await tester.pumpWidget(const MaterialApp(home: FinishPage()));
      await tester.pump();

      expect(
        tester.takeException(),
        isNull,
        reason: 'the finish screen overflowed its ${_se.height}px height',
      );

      expect(
        find.byType(Scrollable),
        findsWidgets,
        reason: 'the finish screen must scroll when the text does not fit',
      );

      await tester.ensureVisible(find.text("Let's Go"));
      await tester.pump();

      final button = tester.getRect(find.text("Let's Go"));
      expect(button.top, greaterThanOrEqualTo(0.0));
      expect(
        button.bottom,
        lessThanOrEqualTo(_se.height),
        reason: "Let's Go sits below the bottom edge of the screen",
      );
      expect(tester.takeException(), isNull);

      await _unmount(tester);
    });
  }
}

/// Applies a real device size and a real accessibility text scale.
///
/// The scale is set on the platform dispatcher rather than by wrapping the tree
/// in a MediaQuery: `MaterialApp` installs its own `MediaQuery.fromView`, which
/// would override an ancestor MediaQuery and quietly make the test run at 1x.
void _useDeviceAndTextScale(WidgetTester tester, Size size, double scale) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Tears the tree down and lets the typewriter's in-flight delay fire.
///
/// Once the widget is unmounted its loop stops after that delay, so this is
/// what keeps the test from failing with a pending timer.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 8));
}
