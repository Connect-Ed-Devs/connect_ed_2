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
/// This screen flattens every assessment across the whole feed, sorts it by
/// urgency, and lets you tick things off (persisted in SharedPreferences).
class AssignmentsPage extends StatefulWidget {
  const AssignmentsPage({super.key});

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

  int get daysUntilDue {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return date.difference(today).inDays;
  }
}

class _AssignmentsPageState extends State<AssignmentsPage> {
  Map<DateTime, CalendarItem>? _calendarData;
  bool _isLoading = true;
  String? _errorMessage;
  bool _showCompleted = false;
  Set<String> _completed = <String>{};

  static const _completedKey = 'assignments_completed';

  @override
  void initState() {
    super.initState();
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

  void _loadCalendarData() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final status = calendarManager.getCacheStatus();
    if (status != CacheStatus.expired) {
      final cached = calendarManager.getCachedData();
      if (cached != null) {
        setState(() {
          _calendarData = cached;
          _isLoading = false;
        });
        return;
      }
    }

    calendarManager
        .fetchData()
        .then((data) {
          if (!mounted) return;
          setState(() {
            _calendarData = data;
            _isLoading = false;
            _errorMessage = null;
          });
        })
        .catchError((error) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorMessage = error.toString();
          });
        });
  }

  /// Every assessment in the feed, flattened and sorted by due date.
  List<_Entry> get _entries {
    final data = _calendarData;
    if (data == null) return const [];

    final entries = <_Entry>[];
    data.forEach((date, item) {
      for (final assessment in item.assessments) {
        entries.add(_Entry(assessment: assessment, date: date));
      }
    });

    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  _Bucket _bucketFor(_Entry entry) {
    if (_completed.contains(entry.id)) return _Bucket.done;
    final days = entry.daysUntilDue;
    if (days < 0) return _Bucket.overdue;
    if (days == 0) return _Bucket.today;
    if (days == 1) return _Bucket.tomorrow;
    if (days <= 7) return _Bucket.thisWeek;
    return _Bucket.later;
  }

  // ---------------------------------------------------------------------------
  // Presentation helpers
  // ---------------------------------------------------------------------------

  /// Deterministic colour per class so the same subject always looks the same.
  Color _colorForClass(String name) {
    if (name.trim().isEmpty) return Colors.grey;
    final hue = (name.hashCode.abs() % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.42, 0.48).toColor();
  }

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

  Color _bucketAccent(_Bucket bucket, BuildContext context) {
    if (bucket == _Bucket.overdue || bucket == _Bucket.today) {
      return Theme.of(context).colorScheme.error;
    }
    if (bucket == _Bucket.done) {
      return Theme.of(
        context,
      ).colorScheme.onSurface.withValues(alpha: 0.45);
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _dueLabel(_Entry entry) {
    return DateFormat('EEE d MMM').format(entry.date);
  }

  String _countdownLabel(_Entry entry) {
    final days = entry.daysUntilDue;
    if (days < 0) {
      final n = days.abs();
      return n == 1 ? '1 day ago' : '$n days ago';
    }
    if (days == 0) return 'Today';
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
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
            else if (_entries.isEmpty)
              _buildEmptyState()
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
    final completedCount = _entries
        .where((e) => _completed.contains(e.id))
        .length;
    final outstanding = _entries.length - completedCount;

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
        if (_entries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: FilterChip(
                label: Text(
                  _showCompleted ? 'Hide done' : 'Show done ($completedCount)',
                ),
                selected: _showCompleted,
                onSelected: (value) {
                  setState(() => _showCompleted = value);
                },
                backgroundColor: theme.colorScheme.surface,
                selectedColor: theme.colorScheme.primary.withValues(
                  alpha: 0.15,
                ),
                checkmarkColor: theme.colorScheme.primary,
                side: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: _showCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
      ],
      bottom: _entries.isEmpty
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

  List<Widget> _buildSections() {
    final theme = Theme.of(context);

    // Group entries, preserving the order the buckets should appear in.
    const order = [
      _Bucket.overdue,
      _Bucket.today,
      _Bucket.tomorrow,
      _Bucket.thisWeek,
      _Bucket.later,
      _Bucket.done,
    ];

    final grouped = <_Bucket, List<_Entry>>{};
    for (final entry in _entries) {
      final bucket = _bucketFor(entry);
      if (bucket == _Bucket.done && !_showCompleted) continue;
      grouped.putIfAbsent(bucket, () => []).add(entry);
    }

    final widgets = <Widget>[];
    for (final bucket in order) {
      final items = grouped[bucket];
      if (items == null || items.isEmpty) continue;

      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _bucketAccent(bucket, context),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _bucketTitle(bucket),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _bucketAccent(bucket, context),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      widgets.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _buildCard(items[index], bucket),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _buildCard(_Entry entry, _Bucket bucket) {
    final theme = Theme.of(context);
    final assessment = entry.assessment;
    final isDone = _completed.contains(entry.id);
    final classColor = _colorForClass(assessment.className);
    final accent = _bucketAccent(bucket, context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _toggleCompleted(entry.id),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.18),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Class colour spine
                  Container(width: 5, color: isDone ? Colors.grey : classColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Row(
                        children: [
                          // Completion toggle
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDone ? accent : accent.withValues(
                                  alpha: 0.5,
                                ),
                                width: 1.8,
                              ),
                              color: isDone ? accent : Colors.transparent,
                            ),
                            child: isDone
                                ? Icon(
                                    Icons.check,
                                    size: 14,
                                    color: theme.colorScheme.surface,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 13),
                          // Title + class
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assessment.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: isDone
                                        ? theme.colorScheme.onSurface
                                            .withValues(alpha: 0.45)
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        assessment.className.isEmpty
                                            ? 'Unclassified'
                                            : assessment.className,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: classColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _dueLabel(entry),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Countdown chip
                          if (!isDone)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _countdownLabel(entry),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
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
                Icons.assignment_turned_in_outlined,
                size: 64,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.28),
              ),
              const SizedBox(height: 18),
              Text(
                'No assignments yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assignments come from your school calendar feed. '
                'Pull down to refresh.',
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
