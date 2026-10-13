import 'package:connect_ed_2/classes/assessment.dart';
import 'package:connect_ed_2/classes/calendar_item.dart';
import 'package:connect_ed_2/main.dart';
import 'package:connect_ed_2/requests/cache_manager.dart';
import 'package:connect_ed_2/requests/calendar_requests.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A dedicated Assignments tab.
///
/// The calendar feed carries assignments as all-day events; they were
/// previously only visible buried inside the Calendar tab, one day at a time.
/// This screen flattens the assessments for a single month, sorts them by
/// urgency, and lets you tick things off (persisted in SharedPreferences).
///
/// A year-long feed holds far more than anyone wants to scroll at once, so the
/// view opens on the current month with a picker for the rest, and finished
/// work collapses into its own dropdown instead of disappearing.
class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key, this.now});

  /// Overrides "today". Urgency grouping and the month the tab opens on both
  /// read the clock, so pinning it is the only way to test either
  /// deterministically. Production callers leave it null.
  final DateTime? now;

  @override
  State<AssignmentsPage> createState() => _AssignmentsPageState();
}

/// Which urgency group an assignment falls into.
enum _Bucket { overdue, today, tomorrow, thisWeek, later, done }

/// An assessment paired with the cache key it was found under.
class _Entry {
  final Assessment assessment;
  final DateTime date;

  const _Entry({required this.assessment, required this.date});

  /// Stable identity used to persist the completed state.
  ///
  /// Keyed on class + title + day (not time) so it survives re-fetches and
  /// stays stable when the same assignment appears on the same day.
  String get id {
    final day = DateFormat('yyyy-MM-dd').format(date);
    return '${assessment.className}|${assessment.title}|$day';
  }

  /// Whole days from [today] until this is due. Negative once it is late.
  int daysUntilDue(DateTime today) => date.difference(today).inDays;
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  Map<DateTime, CalendarItem>? _calendarData;
  bool _isLoading = true;
  String? _errorMessage;

  /// Whether the collapsed "Completed" dropdown has been opened.
  bool _completedExpanded = false;

  Set<String> _completed = <String>{};

  /// Midnight on the first of the month being shown. Opens on the current one.
  late DateTime _selectedMonth;

  /// Midnight today, captured once so every row on a build agrees on "today".
  late final DateTime _today;

  static const _completedKey = 'assignments_completed';

  /// The month [date] falls in, as a value that can be compared and used as a
  /// dropdown key. Day and time are dropped so every day of a month maps to the
  /// same value.
  static DateTime _monthOf(DateTime date) => DateTime(date.year, date.month);

  @override
  void initState() {
    super.initState();
    final now = widget.now ?? DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _selectedMonth = _monthOf(_today);
    _completed = _loadCompleted();
    _loadCalendarData();
  }

  // ---------------------------------------------------------------------------
  // Data
  // ---------------------------------------------------------------------------

  Set<String> _loadCompleted() {
    final stored = prefs.getStringList(_completedKey);
    return stored == null ? <String>{} : stored.toSet();
  }

  Future<void> _persistCompleted() async {
    await prefs.setStringList(_completedKey, _completed.toList());
  }

  void _toggleCompleted(String id) {
    setState(() {
      if (_completed.contains(id)) {
        _completed.remove(id);
      } else {
        _completed.add(id);
      }
    });
    _persistCompleted();
  }

  bool _isDone(_Entry entry) => _completed.contains(entry.id);

  /// Loads assignments, preferring fresh cache over the network.
  ///
  /// Returns a [Future] that completes once the (possibly networked) load has
  /// settled, so `RefreshIndicator.onRefresh` keeps its spinner up until the
  /// refresh is actually done instead of hiding it immediately.
  Future<void> _loadCalendarData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final status = calendarManager.getCacheStatus();
    if (status != CacheStatus.expired) {
      final cached = calendarManager.getCachedData();
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _calendarData = cached;
          _isLoading = false;
        });
        return;
      }
    }

    try {
      final data = await calendarManager.fetchData();
      if (!mounted) return;
      setState(() {
        _calendarData = data;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  /// Every assessment in the feed, flattened and sorted by due date.
  List<_Entry> get _allEntries {
    final data = _calendarData;
    if (data == null) return const [];

    // A feed can carry the same assignment more than once (duplicate VEVENTs
    // in the ICS, or an overlap between cached and freshly fetched data).
    // Collapse those by stable id so the list never shows the same row twice.
    final entries = <_Entry>[];
    final seen = <String>{};
    data.forEach((date, item) {
      for (final assessment in item.assessments) {
        final entry = _Entry(assessment: assessment, date: date);
        if (seen.add(entry.id)) entries.add(entry);
      }
    });

    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  /// The entries that fall inside the month currently being shown.
  List<_Entry> get _monthEntries {
    final month = _selectedMonth;
    return _allEntries
        .where(
          (entry) =>
              entry.date.year == month.year && entry.date.month == month.month,
        )
        .toList();
  }

  /// Months offered by the picker: every month the feed has work for, plus the
  /// current one so opening on "now" is always possible.
  List<DateTime> get _monthsWithEntries {
    final months = <DateTime>{_monthOf(_today)};
    for (final entry in _allEntries) {
      months.add(_monthOf(entry.date));
    }
    return months.toList()..sort((a, b) => a.compareTo(b));
  }

  _Bucket _bucketFor(_Entry entry) {
    if (_isDone(entry)) return _Bucket.done;
    final days = entry.daysUntilDue(_today);
    if (days < 0) return _Bucket.overdue;
    if (days == 0) return _Bucket.today;
    if (days == 1) return _Bucket.tomorrow;
    if (days <= 7) return _Bucket.thisWeek;
    return _Bucket.later;
  }

  // ---------------------------------------------------------------------------
  // Presentation helpers
  // ---------------------------------------------------------------------------

  String _bucketTitle(_Bucket bucket) {
    switch (bucket) {
      case _Bucket.overdue:
        return 'Overdue';
      case _Bucket.today:
        return 'Due today';
      case _Bucket.tomorrow:
        return 'Tomorrow';
      case _Bucket.thisWeek:
        return 'This week';
      case _Bucket.later:
        return 'Later';
      case _Bucket.done:
        return 'Completed';
    }
  }

  String _monthLabel(DateTime month) => DateFormat('MMM yyyy').format(month);

  String _monthLabelLong(DateTime month) =>
      DateFormat('MMMM yyyy').format(month);

  String _dueLabel(_Entry entry) => DateFormat('EEE d MMM').format(entry.date);

  /// The one date label a row carries.
  ///
  /// Relative while that still reads naturally, absolute beyond it, so a row
  /// never shows two competing date strings the way it did with a "Due ..."
  /// line beside a countdown pill.
  String _dueText(_Entry entry) {
    final days = entry.daysUntilDue(_today);
    if (days < 0) {
      final n = days.abs();
      return n == 1 ? '1 day ago' : '$n days ago';
    }
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return _dueLabel(entry);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async => _loadCalendarData(),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildErrorState()
            else if (_allEntries.isEmpty)
              _buildEmptyState()
            else if (_monthEntries.isEmpty)
              _buildEmptyMonthState()
            else
              ..._buildSections(),
            // Clearance so the floating nav bar never covers the last card.
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    final theme = Theme.of(context);
    final monthEntries = _monthEntries;
    final completedCount = monthEntries.where(_isDone).length;
    final outstanding = monthEntries.length - completedCount;

    return SliverAppBar(
      pinned: true,
      expandedHeight: 112,
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 16),
        title: Text(
          'Assignments',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        background: Container(color: theme.colorScheme.surface),
      ),
      actions: [
        if (_allEntries.isNotEmpty) _buildMonthPicker(theme),
      ],
      bottom: _allEntries.isEmpty
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(28),
              child: Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    outstanding == 0
                        ? 'All caught up'
                        : '$outstanding to do',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  /// Picks which month's work is on screen. A year-long feed would otherwise
  /// open on hundreds of rows.
  Widget _buildMonthPicker(ThemeData theme) {
    final months = _monthsWithEntries;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Center(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<DateTime>(
            value: _selectedMonth,
            isDense: true,
            borderRadius: BorderRadius.circular(12),
            dropdownColor: theme.colorScheme.surfaceContainer,
            icon: Icon(
              Icons.expand_more,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            // The trigger stays in the brand blue; the menu itself reads in
            // normal body colour so the options stay legible.
            selectedItemBuilder: (context) => [
              for (final month in months)
                Center(
                  child: Text(
                    _monthLabel(month),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface,
            ),
            items: [
              for (final month in months)
                DropdownMenuItem<DateTime>(
                  value: month,
                  child: Text(_monthLabel(month)),
                ),
            ],
            onChanged: (month) {
              if (month == null) return;
              setState(() => _selectedMonth = month);
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections() {
    const order = [
      _Bucket.overdue,
      _Bucket.today,
      _Bucket.tomorrow,
      _Bucket.thisWeek,
      _Bucket.later,
    ];

    final grouped = <_Bucket, List<_Entry>>{};
    final done = <_Entry>[];
    for (final entry in _monthEntries) {
      if (_isDone(entry)) {
        done.add(entry);
        continue;
      }
      grouped.putIfAbsent(_bucketFor(entry), () => []).add(entry);
    }

    final widgets = <Widget>[];
    for (final bucket in order) {
      final items = grouped[bucket];
      if (items == null || items.isEmpty) continue;
      widgets.add(_buildSectionHeader(_bucketTitle(bucket), items.length));
      widgets.add(_buildList(items));
    }

    if (done.isNotEmpty) {
      widgets.add(_buildCompletedHeader(done.length));
      // Collapsed by default: finished work is reference material, not a
      // to-do list, but it should never be impossible to find again.
      if (_completedExpanded) {
        widgets.add(_buildList(done, done: true));
      }
    }

    return widgets;
  }

  Widget _buildSectionHeader(String title, int count) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedHeader(int count) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => _completedExpanded = !_completedExpanded);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                Text(
                  _bucketTitle(_Bucket.done),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                const Spacer(),
                Text(
                  _completedExpanded ? 'Hide' : 'Show',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
                AnimatedRotation(
                  turns: _completedExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.expand_more,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<_Entry> items, {bool done = false}) {
    final theme = Theme.of(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.separated(
        itemCount: items.length,
        // A hairline indented to the text column, as on the Calendar tab's
        // assessment list - not a box per row.
        separatorBuilder: (context, index) => Divider(
          height: 1,
          thickness: 1,
          indent: 35, // checkbox (22) + its gap (13)
          color: theme.colorScheme.tertiary,
        ),
        itemBuilder: (context, index) =>
            _buildRow(items[index], isDone: done || _isDone(items[index])),
      ),
    );
  }

  /// One assignment, as a row on the canvas rather than a card in a box.
  ///
  /// This used to be a bordered rounded container carrying a 5px accent bar down
  /// its left edge. A coloured left border is the most reliable "generated
  /// rather than designed" tell there is (DESIGN.md 2.1), and the container did
  /// nothing a list does not already do. Matches the Calendar tab's assessment
  /// list.
  Widget _buildRow(_Entry entry, {required bool isDone}) {
    final theme = Theme.of(context);
    final assessment = entry.assessment;
    final days = entry.daysUntilDue(_today);

    return InkWell(
      onTap: () => _toggleCompleted(entry.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The row's only control, so it is the only thing here wearing the
            // brand colour.
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(top: 1),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDone
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  width: 1.6,
                ),
                color: isDone ? theme.colorScheme.primary : Colors.transparent,
              ),
              child: isDone
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: theme.colorScheme.onPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    assessment.title.trim().isEmpty
                        ? 'Untitled assignment'
                        : assessment.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Secondary lines are secondary text; the Calendar tab already
                  // renders class names this way. Colouring every row's class
                  // blue was decoration, not information.
                  Text(
                    assessment.className.isEmpty
                        ? 'Unclassified'
                        : assessment.className,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Plain right-aligned text where the filled countdown pill used to
            // be. The colour is doing a job: error once it is due today or late.
            Text(
              _dueText(entry),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDone
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                    : (days <= 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface.withValues(alpha: 0.55)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return SliverFillRemaining(
      hasScrollBody: false,
      child: _centeredMessage(
        theme,
        icon: Icons.assignment_turned_in_outlined,
        title: 'No assignments yet',
        body:
            'Assignments come from your school calendar feed. '
            'Pull down to refresh.',
      ),
    );
  }

  /// The month is empty but other months in the feed are not: say so, rather
  /// than showing the same "no assignments" copy and looking broken.
  Widget _buildEmptyMonthState() {
    final theme = Theme.of(context);
    return SliverFillRemaining(
      hasScrollBody: false,
      child: _centeredMessage(
        theme,
        icon: Icons.event_available_outlined,
        title: 'Nothing due in ${_monthLabelLong(_selectedMonth)}',
        body: 'Pick another month from the list above, or pull down to refresh.',
      ),
    );
  }

  Widget _centeredMessage(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 64,
                color: theme.colorScheme.error.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 18),
              Text(
                'Could not load assignments',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadCalendarData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
