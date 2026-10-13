import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/classes/widget_snapshot.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';

// The platform half. Web and desktop get the no-op: `home_widget` cannot be
// compiled for the web at all, so pulling it in unconditionally would break the
// browser build.
import 'widget_bridge_stub.dart' if (dart.library.io) 'widget_bridge_io.dart';

/// Hands today's essentials to the home-screen and lock-screen widgets.
///
/// This is the only entry point callers need; it decides whether there is a
/// widget platform underneath and never lets a widget failure escape into the
/// app.
class WidgetBridge {
  /// True only on Android and iOS.
  static bool get isSupported => widgetsSupported;

  /// Publishes [snapshot] to the native side.
  static Future<void> publish(WidgetSnapshot snapshot) async {
    if (!widgetsSupported) return;
    try {
      await saveSnapshotToPlatform(snapshot);
    } catch (e) {
      // A widget that cannot refresh must never take the app down with it, and
      // there is nothing useful to show the user about it.
      print('Widget refresh failed: $e');
    }
  }

  /// Rebuilds the snapshot from whatever calendar is already cached and
  /// publishes it.
  ///
  /// Reading the cache rather than fetching keeps this cheap enough to call on
  /// every launch; the widgets are refreshed whenever the app runs, and there is
  /// no background refresh yet (see WIDGET.md).
  static Future<void> publishFromCache({DateTime? now}) async {
    if (!widgetsSupported) return;
    try {
      final cached = calendarManager.getCachedData();
      await publish(
        WidgetSnapshot.build(
          calendar: cached is Map<DateTime, CalendarItem> ? cached : null,
          now: now,
        ),
      );
    } catch (e) {
      print('Widget refresh failed: $e');
    }
  }
}
