# Home-screen and lock-screen widgets

A widget showing what a student needs before they unlock their phone: the next
class with its time and room, and how much is due today. It renders on the
Android home screen and (Android 14+) lock screen, and on the iOS home screen
plus all three lock-screen accessory families.

**Status: the Dart half is tested; the native half has never been compiled.**
This machine has no Android SDK, no Java and no Xcode, so nothing below the Dart
layer has been built or run — see [What is not verified](#what-is-not-verified).

---

## 1. How it fits together

```
  calendar cache (SharedPreferences, written by the app)
            │
            ▼
  lib/classes/widget_snapshot.dart      ← builds the payload. Pure, unit-tested.
            │
            ▼
  lib/requests/widget_bridge.dart       ← platform gate + error isolation
            │
     ┌──────┴───────┐
     ▼              ▼
  widget_bridge_io  widget_bridge_stub
  (Android/iOS)     (web/desktop: no-op)
     │
     ▼
  home_widget 0.9.2+1
     │
     ├─ Android → SharedPreferences file `HomeWidgetPreferences`
     │              read by ConnectEdWidgetProvider.kt
     └─ iOS     → app group `group.com.example.connectEd`
                    read by ConnectEdWidget.swift
```

`WidgetBridge.publishFromCache()` is called from two places: `MyHomePage.initState`
(so a normal launch refreshes it) and the Home tab after a fresh calendar fetch
(so the first ever run is correct too, rather than one launch behind).

**Why the conditional import.** `home_widget` imports `dart:io` unconditionally
and declares only Android/iOS. Importing it directly would break the web build,
which is how this app is currently tested, so `widget_bridge.dart` picks
`widget_bridge_io.dart` only where `dart:library.io` exists and the no-op
`widget_bridge_stub.dart` everywhere else. Callers never branch on the platform;
`WidgetBridge.isSupported` answers that question.

## 2. The contract

These names are duplicated across three languages. Changing one side alone makes
the widget go quiet, not fail loudly, so treat this table as the interface:

| key | type | meaning |
|---|---|---|
| `has_data` | bool | false until the app has published anything |
| `next_title` | String | next class, or `No classes coming up`; never empty when `has_data` |
| `next_time` | String | `1:30 PM – 2:45 PM`; empty when there is no class |
| `next_room` | String | expanded through `room_directory.dart`; empty when the feed has none |
| `due_today` | int | assessments due today |
| `due_next_title` | String | the next thing due, when nothing is due today |
| `due_next_when` | String | `Today` / `Tomorrow` / `Mon 16 Mar` |

Identifiers, also shared:

| what | value |
|---|---|
| Android provider class | `com.example.connect_ed_2.ConnectEdWidgetProvider` |
| iOS widget kind | `ConnectEdWidget` |
| iOS app group | `group.com.example.connectEd` |

`test/widget_snapshot_test.dart` pins the key set, the types, and the rule for
each value, including that an ongoing class is skipped — the widget must not
disagree with the Home tab's "Up Next" card.

## 3. Rules the payload follows

- **A class already under way is not "next".** Home shows the class after it, so
  the widget does too.
- **Days with no schedule are skipped**, up to a week ahead, which is what makes
  a Monday widget useful when opened on a Friday.
- **`has_data` describes the app, not the day.** A cached week with nothing on it
  still reports `true` and says `No classes coming up`, so readers only show
  their "open the app" state for a genuine fresh install.
- **Rooms go through the shared directory**, so filling in the school's
  code-to-building list updates the widgets with no native change.

## 4. Android

Files: `android/app/src/main/kotlin/com/example/connect_ed_2/ConnectEdWidgetProvider.kt`,
`android/app/src/main/res/layout/connect_ed_widget.xml`,
`android/app/src/main/res/xml/connect_ed_widget_info.xml`, and the `<receiver>`
added to `AndroidManifest.xml`.

Nothing further is needed to build it — but it has not been built. On a machine
with the Android SDK: `flutter build apk --debug`, add the widget from the home
screen, then check `adb logcat` if it renders empty. Long-press → *Widgets* →
Connect-Ed.

Two honest gaps: the strings and colours are inline literals (there is no
`res/values/colors.xml` or `strings.xml` in this project yet), and
`updatePeriodMillis="1800000"` only re-reads the last published values, so
learning *new* data without opening the app needs a background callback
(`HomeWidget.registerBackgroundCallback`), which is not wired up.

## 5. iOS

Files: `ios/ConnectEdWidget/` — the Swift extension, its plist, and a README with
the click-by-click Xcode steps. The short version:

1. Open `ios/Runner.xcworkspace` (**not** `Runner.xcodeproj`).
2. File → New → Target → **Widget Extension**, named `ConnectEdWidget`, with
   "Include Live Activity" and "Include Configuration App Intent" **unchecked**
   (the code uses `StaticConfiguration`).
3. Replace the generated sources with `ios/ConnectEdWidget/*`, keeping exactly
   one `@main`.
4. Set the deployment target to **iOS 16.0** (the accessory families need it).
5. Add the App Group `group.com.example.connectEd` to **both** the Runner and the
   extension, so `saveWidgetData` and the widget read the same container.

The entitlements file (`ios/Runner/Runner.entitlements`) does not exist yet;
enabling App Groups in Xcode is what creates it.

## 6. Platform limits worth knowing

- **iOS lock-screen widgets** are the `.accessory*` families, iOS 16+. The
  system renders them monochrome/vibrant, so colour there is a hint, not a
  design — which is why the accessory views let the system tint them.
- **Android lock-screen widgets** need Android 14+ *and* a launcher that supports
  them; on older versions the same widget is home-screen only. That is why the
  info XML declares `widgetCategory="home_screen|keyguard"`.
- **Neither platform lets a widget run arbitrary code on a schedule.** A widget
  is a snapshot the app publishes; keeping it fresh while the app is closed needs
  a background task (WorkManager on Android, a WidgetKit timeline or background
  URL session on iOS).

## 7. What is not verified

- **No native code has been compiled.** No Android SDK, no Java, no Xcode on this
  machine. Expect a first-build typo; the layout, the Kotlin and the Swift are
  written to be reviewed, not proven.
- **The iOS extension target does not exist yet.** Creating it means editing
  `Runner.xcodeproj` in Xcode; hand-editing that file from here would have been
  guesswork.
- **The key storage matches by inspection, not by device test.** Reading
  `home_widget` 0.9.2+1's own source confirms the three things both readers rely
  on: iOS stores the values into the app group's `UserDefaults` as native
  `Bool`/`Int`/`String` (so Swift's `bool(forKey:)`/`integer(forKey:)` work),
  Android writes them into `HomeWidgetPreferences`, and `updateWidget` resolves
  `qualifiedAndroidName` verbatim. None of that has run on a device. If the
  widget shows its prompt after the app has run, `HomeWidget.getWidgetData<String>('next_title')`
  from Dart is the cheapest way to see the real store.
- **`home_widget` is a new dependency, pinned to `0.9.2+1`.** It is the only
  dependency this feature adds, and the devs will need `flutter pub get`.
  It is pinned rather than caret-ranged on purpose: **0.9.3 and later require
  Flutter >= 3.38.1**, which would raise this project's SDK floor
  (`flutter: ">=3.32.0"` in `pubspec.lock`) for every contributor. 0.9.2+1
  exposes the same API surface we use — `saveWidgetData`, `updateWidget`,
  `setAppGroupId` — so the pin costs nothing. Lift it the day the project moves
  to Flutter 3.38+.

  `pubspec.lock` therefore gains **one** entry, and deliberately nothing else.
  Running `flutter pub get` on a newer Flutter than the project targets also
  bumps the SDK-pinned test packages (`meta`, `matcher`, `test_api`,
  `leak_tracker`) and the `dart:` floor in the lock's `sdks:` section; those
  bumps are artifacts of the local toolchain, not of adding a dependency, and
  committing them would raise the floor the pin exists to protect. The entry was
  written by hand and checked with `flutter pub get --enforce-lockfile`, which
  accepts `home_widget 0.9.2+1` and flags only those SDK-pinned packages.

Verified here instead: `flutter test` (87 tests) covers the payload contract and
builder rules, `flutter analyze` covers the new Dart files, and `flutter build web`
still succeeds with the dependency added — which is the specific thing the
conditional import exists to protect.
