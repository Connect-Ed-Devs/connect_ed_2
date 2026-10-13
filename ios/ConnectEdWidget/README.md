# Connect-Ed widgets (iOS)

Home-screen and lock-screen widgets for Connect-Ed. They show **Up Next** — the
next class with its time and room — plus how many assessments are due today.

The widget never talks to Firebase. The Flutter app computes a small snapshot
and hands it to the `home_widget` plugin, which writes it into a shared App
Group; the extension just reads those keys back.

> **These files cannot be built on Windows.** There is no Xcode on the machine
> this was written on, so the Swift has never been compiled and the extension
> target has never been created. The steps below are what an Xcode user has to
> do; expect to fix a typo or two on the first build.

## Files here

| file | what it is |
|---|---|
| `ConnectEdWidget.swift` | the whole extension: timeline provider, four widget layouts, `@main` bundle |
| `Info.plist` | declares the `com.apple.widgetkit-extension` extension point |
| `README.md` | this file |

Do **not** hand-edit `ios/Runner.xcodeproj/project.pbxproj`. Creating a target
by editing that file by hand corrupts the project in ways that are painful to
unpick. Use Xcode.

## Setup

1. **Prerequisites** — macOS, **Xcode 15+** (needed for the iOS 17
   `containerBackground` API the code compiles against), an iOS 16+ device or
   simulator, and `flutter pub get` already run (`home_widget` is in
   `pubspec.yaml`).

2. **Open the workspace, not the project**: `ios/Runner.xcworkspace`. Opening
   `Runner.xcodeproj` skips the CocoaPods integration and the App Group
   capability will appear not to work.

3. **Add the target** — File → New → Target… → iOS → **Widget Extension**.
   - Product Name: `ConnectEdWidget` (the kind string in the Swift must stay
     `ConnectEdWidget`; the product name is free, but matching keeps it obvious).
   - **Uncheck** "Include Live Activity" and "Include Configuration App Intent".
     The widget uses `StaticConfiguration`, so an intent is not just unused, it
     changes the configuration type and will not compile.
   - Finish → "Activate scheme?" → Cancel is fine.

4. **Replace the generated sources** — Xcode creates `ConnectEdWidget.swift`,
   `ConnectEdWidgetBundle.swift` and `Info.plist` inside the new group. Delete
   the two `.swift` files it generated and add `ConnectEdWidget.swift` and
   `Info.plist` from this folder instead (drag them into the target; check
   **Target Membership** is `ConnectEdWidget` only, and *not* Runner).
   There must be exactly **one** `@main` in the extension — the bundle in this
   file is it.

5. **Bundle identifier** — set the extension's to
   `com.example.connect_ed_2.ConnectEdWidget`. It must start with the Runner's
   bundle id or the app cannot embed it.

6. **Deployment target** — on the **ConnectEdWidget** target, set **iOS 16.0**.
   That is the floor for the accessory (lock-screen) families. The code guards
   the iOS 17-only `containerBackground` call with `#available`, so it still
   compiles against an iOS 16 deployment target.

7. **App Group on BOTH targets** — for `Runner` *and* `ConnectEdWidget`:
   Signing & Capabilities → **+ Capability** → **App Groups** → add
   `group.com.example.connectEd`.
   This is the step that silently fails most often: **no entitlements file
   exists in the repo yet**, so Xcode will create
   `ios/Runner/Runner.entitlements` (and one for the extension) when you turn
   the capability on. Both targets need the *same* group id, spelled the same.

8. **Frameworks** — `SwiftUI` and `WidgetKit` are linked automatically by the
   template. If you assembled the target by hand, add both under Build Phases →
   Link Binary With Libraries (SDK frameworks — do not embed them).

9. **Match it in Dart** — `lib/requests/widget_bridge.dart` calls
   `HomeWidget.setAppGroupId('group.com.example.connectEd')` before saving. If
   that id and the capability disagree, the app writes to its own defaults and
   the widget shows the "Open the app…" prompt forever.

10. **Try it** — `flutter run` on an iOS 16+ device, then open the app once so it
    publishes a snapshot. Home screen → long-press → Edit → Add Widget →
    Connect-Ed. Lock screen → long-press → Customize → Add Widget →
    Connect-Ed (the inline, rectangular and circular ones live in that list).

## Keys the widget reads

Written by `HomeWidget.saveWidgetData`, read from
`UserDefaults(suiteName: "group.com.example.connectEd")`:

| key | type | shown as |
|---|---|---|
| `next_title` | String | the class name |
| `next_time` | String | `1:30 PM` |
| `next_room` | String | `D-2` (joined with the time as `1:30 PM · D-2`) |
| `due_today` | int | the count; the circular widget shows only this |
| `due_next_title` | String | reserved — not drawn yet |
| `due_next_when` | String | reserved — not drawn yet |
| `has_data` | bool | false → the calm prompt instead of empty fields |

If the widget shows the prompt even though the app has run, check in order: the
App Group on both targets, `setAppGroupId` being called, then whether the plugin
namespaced the keys. `HomeWidget.getWidgetData<String>('next_title')` from Dart
is the quickest way to see what actually landed.

## Known behaviour and limits

- **Refresh**: the timeline asks for an update hourly, but the *data* only
  changes when the app publishes a snapshot (opening the app is enough). There
  is no background refresh — `HomeWidget.registerBackgroundCallback` plus a
  `BGAppRefreshTask` would be the next step.
- **Colour**: the navy `#004270` fill is the home-screen size only. Lock-screen
  accessory widgets are rendered by the system in a vibrant monochrome style, so
  forcing a colour there looks wrong; the code passes `nil` and lets the system
  tint the text.
- **iOS 16 cosmetics**: the navy fill is inset on iOS 16 because
  `containerBackground` arrives in iOS 17. Nothing breaks; it just looks less
  full-bleed.
- **Layout** follows the repo's `DESIGN.md`: one flat, left-aligned column, no
  accent stripe, no icon-in-a-rounded-square, no nested cards. Keep it that way
  when changing these views.
