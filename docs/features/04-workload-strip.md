# 04: Week-ahead workload strip

## Decision

A row of the next seven days at the top of the Assignments tab (below the
app bar, only once the tab has loaded and has at least one item). Each column
shows the weekday letter, the date and the count of incomplete items due that
day.

- `weekWorkload` (`lib/classes/week_workload.dart`) is a pure function: feed
  assignments from the calendar cache plus dated personal tasks, minus ids in
  the completed set, grouped into today and the six days after it. Feed
  duplicates are collapsed by `feedCompletionId`, the same id the tab and the
  reminder scheduler use, so a ticked item leaves the strip, the list and the
  reminders together. Overdue items are not counted; they are outside the week.
- Days are generated as `DateTime(y, m, d + i)` and matched by y/m/d. A
  `.difference().inDays` count is a day short across a clock change; the test
  starts the week on 8 March 2026, when clocks go forward.
- `WeekStrip` (`lib/frontend/assignments/week_strip.dart`) draws it. The
  heaviest day's count is bold in `primary` (all tied days if several tie);
  empty days show a muted dash. Today is bold text, no pill.
- Tapping a day **filters** the list to that day; tapping it again, or any
  other day, clears or moves the filter. Days with nothing due do not respond.
  The selected date is underlined.

## Why filter, not scroll

The list is grouped by urgency bucket (Overdue, Today, This week...) inside
one selected month, not by day, so there is no per-day section to scroll to.
Scrolling would need a section per day or item keys across a lazy sliver
list. Filtering reuses `_monthEntries`: with a day selected it returns that
day's entries from every month, so a week that crosses a month end works. The
"N to do" line under the title follows the filter.

## Rejected

- Scroll to day: needs per-day anchors in a lazy list, see above.
- A filled pill or tinted cell for today or the heaviest day: DESIGN.md 2.2.
- Reusing `buildReminders` for the gathering: it returns reminder times, not
  due days, and drops items whose reminder is already past. The loop is small
  enough that sharing `feedCompletionId` is the part that has to agree.

## Not verified

- Not run on a device; checked in widget tests at a 1200 px wide surface only.
  Seven columns on a 360 px phone leave about 48 px each, which fits two-digit
  counts but has not been looked at.
- The weekday letter is the locale's narrow form, so Tuesday and Thursday both
  read "T" in English. The semantics label carries the full date and count.
- Selected-day filtering leaves the month picker showing the previous month.
