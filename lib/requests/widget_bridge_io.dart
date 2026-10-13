/// The real widget publisher, compiled only where `dart:io` exists.
///
/// Selected by the conditional import in `widget_bridge.dart`; the web build
/// gets `widget_bridge_stub.dart` instead, because `home_widget` imports
/// `dart:io` and the web compiler rejects that.
library;

import 'dart:io';

import 'package:connect_ed_2/classes/widget_snapshot.dart';
import 'package:home_widget/home_widget.dart';

/// True only where a widget can exist.
bool get widgetsSupported => Platform.isAndroid || Platform.isIOS;

/// Writes the snapshot where the native widgets read it, then asks them to
/// redraw.
///
/// Android: the `HomeWidgetPreferences` SharedPreferences file that
/// `ConnectEdWidgetProvider.kt` reads.
/// iOS: the `group.com.example.connectEd` app group that `ConnectEdWidget.swift`
/// reads.
///
/// Both readers depend on the key names in [WidgetSnapshot.toMap]; changing one
/// side alone makes the widget go quiet rather than fail loudly, which is why
/// `test/widget_snapshot_test.dart` pins the key set.
Future<void> saveSnapshotToPlatform(WidgetSnapshot snapshot) async {
  await HomeWidget.setAppGroupId(widgetAppGroupId);

  for (final entry in snapshot.toMap().entries) {
    await HomeWidget.saveWidgetData<Object?>(
      entry.key,
      entry.value,
      // Passing it per call as well as setting it once: the group id is what
      // makes the iOS side's UserDefaults container the same one the widget
      // extension reads.
      appGroupId: widgetAppGroupId,
    );
  }

  // `qualifiedAndroidName` is used verbatim, unlike `androidName`, which the
  // plugin prefixes with the package name.
  await HomeWidget.updateWidget(
    qualifiedAndroidName: widgetAndroidProvider,
    iOSName: widgetIOSWidgetKind,
  );
}
