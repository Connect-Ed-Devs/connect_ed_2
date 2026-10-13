/// Web (and desktop) have no lock-screen or home-screen widgets, and
/// `home_widget` cannot even be compiled there: it imports `dart:io`, which the
/// web compiler rejects. So the real implementation lives in
/// `widget_bridge_io.dart`, selected by a conditional import in
/// `widget_bridge.dart`, and this no-op stands in everywhere else.
///
/// Keeping the two files behind one interface means callers never branch on the
/// platform themselves.
library;

import 'package:connect_ed_2/classes/widget_snapshot.dart';

/// No widget platform here.
bool get widgetsSupported => false;

/// Does nothing, on purpose.
Future<void> saveSnapshotToPlatform(WidgetSnapshot snapshot) async {}
