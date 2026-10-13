//
//  ConnectEdWidget.swift
//  Connect-Ed
//
//  Home-screen and lock-screen widget. Reads the snapshot the Flutter app
//  writes through the `home_widget` plugin into the shared App Group, so it
//  never talks to Firebase itself.
//
//  Layout rules follow the repo's DESIGN.md: one flat, left-aligned column of
//  text on a single solid brand colour. No accent stripes down an edge, no
//  icon in a rounded square, no nested cards.
//

import SwiftUI
import WidgetKit

// MARK: - Shared contract

/// Must match the App Group enabled on BOTH the Runner target and this
/// extension, and `HomeWidget.setAppGroupId` in Dart (`lib/requests/widget_bridge.dart`).
private enum Shared {
    static let appGroup = "group.com.example.connectEd"

    // Written by HomeWidget.saveWidgetData(...) in Dart. Plain string keys -
    // the plugin stores them as-is in the group's UserDefaults.
    static let nextTitle = "next_title"
    static let nextTime = "next_time"
    static let nextRoom = "next_room"
    static let dueNextTitle = "due_next_title"
    static let dueNextWhen = "due_next_when"
    static let dueToday = "due_today"
    static let hasData = "has_data"
}

/// The brand navy from `lib/frontend/setup/styles.dart` (`#004270`).
private let connectEdNavy = Color(red: 0.0, green: 0.259, blue: 0.439)

// MARK: - Entry

struct UpNextEntry: TimelineEntry {
    let date: Date
    let hasData: Bool
    let title: String
    let time: String
    let room: String
    let dueToday: Int

    /// Reads the snapshot, failing soft.
    ///
    /// Every read is defaulted, so the widget renders something calm on a
    /// device where the app has never run, the App Group is misconfigured, or
    /// the keys are absent - never an empty box full of placeholders.
    static func read(at date: Date = Date()) -> UpNextEntry {
        let defaults = UserDefaults(suiteName: Shared.appGroup) ?? .standard
        return UpNextEntry(
            date: date,
            hasData: defaults.bool(forKey: Shared.hasData),
            title: defaults.string(forKey: Shared.nextTitle) ?? "",
            time: defaults.string(forKey: Shared.nextTime) ?? "",
            room: defaults.string(forKey: Shared.nextRoom) ?? "",
            dueToday: defaults.integer(forKey: Shared.dueToday)
        )
    }

    /// "1:30 PM · D-2", collapsing whatever is missing.
    var detail: String {
        [time, room].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    var dueLabel: String { dueToday == 1 ? "1 due today" : "\(dueToday) due today" }

    var isUsable: Bool { hasData && !title.isEmpty }
}

// MARK: - Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UpNextEntry {
        UpNextEntry(
            date: Date(),
            hasData: true,
            title: "Chemistry",
            time: "1:30 PM",
            room: "D-2",
            dueToday: 2
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UpNextEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : UpNextEntry.read())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UpNextEntry>) -> Void) {
        let now = Date()
        let entry = UpNextEntry.read(at: now)
        // The app pushes a fresh snapshot whenever it loads its data, so this
        // hourly refresh only exists to keep things honest if the app is not
        // opened again - WidgetKit budgets these, so an hour is a cheap ask.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: now)
            ?? now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Views

struct ConnectEdWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: UpNextEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            inline
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        default:
            small
        }
    }

    // Home screen.
    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            if entry.isUsable {
                Text("Up Next")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if !entry.detail.isEmpty {
                    Text(entry.detail)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(entry.dueLabel)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            } else {
                OpenPrompt(alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetBackground(connectEdNavy)
    }

    // Lock screen, wide.
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if entry.isUsable {
                Text("Up Next").font(.caption2)
                Text(entry.title).font(.headline).lineLimit(1)
                Text(entry.detail.isEmpty ? entry.dueLabel : entry.detail)
                    .font(.caption2)
            } else {
                OpenPrompt(alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Accessory families draw over the wallpaper, so the system tint is
        // the background - forcing the brand navy here would just look wrong.
        .widgetBackground(nil)
    }

    // Lock screen, circle: the due-today count, which is the one number that
    // fits without truncating.
    private var circular: some View {
        VStack(spacing: 0) {
            if entry.hasData {
                Text("\(entry.dueToday)").font(.title2).bold()
                Text("due").font(.caption2)
            } else {
                Image(systemName: "calendar")
            }
        }
        .widgetBackground(nil)
    }

    // Lock screen, one line.
    private var inline: some View {
        Text(inlineText)
    }

    private var inlineText: String {
        guard entry.isUsable else { return "Open Connect-Ed" }
        var parts = [entry.title]
        if !entry.time.isEmpty { parts.append(entry.time) }
        if entry.dueToday > 0 {
            parts.append(entry.dueToday == 1 ? "1 due" : "\(entry.dueToday) due")
        }
        return parts.joined(separator: " · ")
    }
}

/// Shown when the app has not written a snapshot yet.
private struct OpenPrompt: View {
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text("Connect-Ed")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Open the app to load your timetable")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
        }
    }
}

// MARK: - iOS 16 / 17 background

private extension View {
    /// Widgets must declare a container background, but the API only exists on
    /// iOS 17. Before that, paint the colour directly; accessory families pass
    /// nil and stay transparent.
    @ViewBuilder
    func widgetBackground(_ color: Color?) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) { color ?? Color.clear }
        } else {
            if let color = color {
                background(color)
            } else {
                self
            }
        }
    }
}

// MARK: - Widget

struct ConnectEdWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ConnectEdWidget", provider: Provider()) { entry in
            ConnectEdWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Connect-Ed")
        .description("Your next class and what's due today.")
        .supportedFamilies([
            .systemSmall,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCircular,
        ])
    }
}

@main
struct ConnectEdWidgetBundle: WidgetBundle {
    var body: some Widget {
        ConnectEdWidget()
    }
}
