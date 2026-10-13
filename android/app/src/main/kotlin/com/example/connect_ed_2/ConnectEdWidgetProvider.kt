package com.example.connect_ed_2

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews

/**
 * Home-screen, and (Android 14+) lock-screen, widget for Connect-Ed.
 *
 * It shows what the Flutter side publishes through the `home_widget` plugin.
 * That plugin writes every value into a single SharedPreferences file, so this
 * class is the one place that knows the wire format:
 *
 *   file : "HomeWidgetPreferences"   (HomeWidgetPlugin.PREFERENCES, home_widget 0.9.2+1)
 *   keys : has_data        Bool   - false/absent until the app has run at least once
 *          next_title      String - next class, e.g. "Chemistry"
 *          next_time       String - when it starts, e.g. "1:30 PM"
 *          next_room       String - its room; empty when the feed has none
 *          due_today       Int    - assessments due today
 *          due_next_title  String - next upcoming assessment
 *          due_next_when   String - "Today" / "Tomorrow" / "Mon 20 Oct"
 *
 * Wiring lives in `lib/requests/widget_bridge.dart`; the iOS widget reads the
 * same keys out of the shared App Group.
 *
 * Values are read through [asText] rather than `getString`/`getInt`: the
 * plugin's store is untyped, so a count published as an Int would throw
 * ClassCastException inside the launcher if it were ever read as a String.
 */
class ConnectEdWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val views = buildViews(context, prefs)
        // One RemoteViews is safe to reuse: every id it touches is set on
        // every pass, including the ones this build hides.
        for (appWidgetId in appWidgetIds) {
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun buildViews(context: Context, prefs: SharedPreferences): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.connect_ed_widget)
        views.setOnClickPendingIntent(R.id.widget_root, openApp(context))

        val hasData = prefs.asText(KEY_HAS_DATA)?.lowercase() == "true"
        if (!hasData) {
            // The app has never published anything - a fresh install, or the
            // widget was added before it was ever opened. Say so plainly rather
            // than showing an invented class, a zero, or an empty box.
            views.setTextViewText(R.id.widget_label, APP_NAME)
            views.setTextViewText(R.id.widget_title, EMPTY_STATE)
            views.setViewVisibility(R.id.widget_time, View.GONE)
            views.setViewVisibility(R.id.widget_room, View.GONE)
            views.setViewVisibility(R.id.widget_due, View.GONE)
            return views
        }

        val title = prefs.asText(KEY_NEXT_TITLE).orEmpty()
        views.setTextViewText(R.id.widget_title, title.ifEmpty { EMPTY_STATE })

        val time = prefs.asText(KEY_NEXT_TIME).orEmpty()
        views.setTextViewText(R.id.widget_time, time)
        views.setViewVisibility(R.id.widget_time, visibilityOf(time))

        // Hidden rather than left blank when the feed carries no room, so the
        // line never trails a separator with nothing after it.
        val room = prefs.asText(KEY_NEXT_ROOM).orEmpty()
        views.setTextViewText(R.id.widget_room, room)
        views.setViewVisibility(R.id.widget_room, visibilityOf(room))

        val due = dueLine(prefs)
        views.setTextViewText(R.id.widget_due, due)
        views.setViewVisibility(R.id.widget_due, visibilityOf(due))

        return views
    }

    /**
     * How many assessments are due today when there are any, otherwise the next
     * one coming up. Empty when there is nothing to say, so the row can hide.
     */
    private fun dueLine(prefs: SharedPreferences): String {
        val dueToday = prefs.asText(KEY_DUE_TODAY)?.toIntOrNull() ?: 0
        if (dueToday > 0) {
            return if (dueToday == 1) "1 due today" else "$dueToday due today"
        }

        val nextTitle = prefs.asText(KEY_DUE_NEXT_TITLE).orEmpty()
        if (nextTitle.isEmpty()) return ""

        val whenLabel = prefs.asText(KEY_DUE_NEXT_WHEN).orEmpty()
        return if (whenLabel.isEmpty()) nextTitle else "$nextTitle \u00b7 $whenLabel"
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        // FLAG_IMMUTABLE is mandatory from API 31; nothing here mutates it.
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun visibilityOf(value: String): Int =
        if (value.isEmpty()) View.GONE else View.VISIBLE

    /**
     * Reads any stored value as text, whatever type it was written as.
     * [SharedPreferences.getAll] cannot throw on a type mismatch, where the
     * typed getters can.
     */
    private fun SharedPreferences.asText(key: String): String? =
        all[key]?.toString()?.takeIf { it.isNotBlank() }

    private companion object {
        const val PREFERENCES = "HomeWidgetPreferences"

        const val KEY_HAS_DATA = "has_data"
        const val KEY_NEXT_TITLE = "next_title"
        const val KEY_NEXT_TIME = "next_time"
        const val KEY_NEXT_ROOM = "next_room"
        const val KEY_DUE_TODAY = "due_today"
        const val KEY_DUE_NEXT_TITLE = "due_next_title"
        const val KEY_DUE_NEXT_WHEN = "due_next_when"

        // Strings would normally live in strings.xml for translation; this slice
        // may not add resource files, so they are inline for now.
        const val APP_NAME = "Connect-Ed"
        const val EMPTY_STATE = "Open Connect-Ed"
    }
}
