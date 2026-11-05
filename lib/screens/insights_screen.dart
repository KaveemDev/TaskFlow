import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/providers.dart';
import '../models/task_model.dart';
import '../models/focus_session_model.dart';
import '../services/insights_math.dart';
import '../widgets/segmented_control.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

/// One bar in the period chart.
class _Bar {
  _Bar(this.label, this.minutes, {this.current = false, this.future = false});
  final String label;
  final int minutes;
  final bool current;
  final bool future;
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  InsightPeriod _period = InsightPeriod.week;
  int _offset = 0; // 0 = this week/month/year, -1 = the one before, ...
  bool _byCategory = false;

  String get _unit => switch (_period) {
    InsightPeriod.week => 'week',
    InsightPeriod.month => 'month',
    InsightPeriod.year => 'year',
  };

  String _rangeLabel(DateTime start, DateTime end) {
    if (_period == InsightPeriod.year) return '${start.year}';
    if (_period == InsightPeriod.month)
      return DateFormat('MMMM y').format(start);
    final last = addDays(end, -1);
    return start.month == last.month
        ? '${start.day} – ${DateFormat('d MMMM').format(last)}'
        : '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM').format(last)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
    final sessions =
        ref.watch(focusSessionsStreamProvider).value ?? const <FocusSession>[];
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);

    final (start, end) = periodBounds(_period, now, _offset);
    final (prevStart, prevEnd) = periodBounds(_period, now, _offset - 1);
    final inPeriod = sessionsIn(sessions, start, end);
    final inPrev = sessionsIn(sessions, prevStart, prevEnd);
    final total = totalMinutes(inPeriod);
    bool doneIn(Task t, DateTime a, DateTime b) =>
        t.isCompleted &&
        t.dueDate != null &&
        !t.dueDate!.isBefore(a) &&
        t.dueDate!.isBefore(b);
    final tasksDone = tasks.where((t) => doneIn(t, start, end)).length;
    final tasksDonePrev = tasks
        .where((t) => doneIn(t, prevStart, prevEnd))
        .length;
    final (streak, bestStreak) = streaks(sessions, now);

    final bars = _bars(sessions, start, end, today);
    final elapsed = bars.where((b) => !b.future).length;
    final average = elapsed == 0 ? 0 : total ~/ elapsed;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            ScreenHeader(
              subtitle:
                  'All time · ${sessions.length} sessions · ${formatMinutes(totalMinutes(sessions))}',
              title: 'Insights',
              actions: [
                SquareIconButton(
                  icon: LucideIcons.plus,
                  tooltip: 'Log a focus session',
                  onPressed: () =>
                      _showAddFocusRecordModal(context, DateTime.now()),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: kScreenPadding,
              child: SegmentedControl<InsightPeriod>(
                value: _period,
                options: const {
                  InsightPeriod.week: 'Week',
                  InsightPeriod.month: 'Month',
                  InsightPeriod.year: 'Year',
                },
                onChanged: (p) => setState(() {
                  _period = p;
                  _offset = 0;
                }),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous $_unit',
                    icon: const Icon(LucideIcons.chevronLeft, size: 20),
                    onPressed: () => setState(() => _offset--),
                  ),
                  Expanded(
                    child: Text(
                      _offset == 0
                          ? 'This $_unit · ${_rangeLabel(start, end)}'
                          : _rangeLabel(start, end),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next $_unit',
                    icon: const Icon(LucideIcons.chevronRight, size: 20),
                    onPressed: _offset >= 0
                        ? null
                        : () => setState(() => _offset++),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: kScreenPadding,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _stat(
                          theme,
                          'Focus',
                          formatMinutes(total),
                          _trend(total - totalMinutes(inPrev), formatMinutes),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _stat(
                          theme,
                          'Sessions',
                          '${inPeriod.length}',
                          _trend(inPeriod.length - inPrev.length, (n) => '$n'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _stat(
                          theme,
                          'Tasks done',
                          '$tasksDone',
                          _trend(tasksDone - tasksDonePrev, (n) => '$n'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _stat(
                          theme,
                          'Streak',
                          '$streak ${streak == 1 ? 'day' : 'days'}',
                          ('Best $bestStreak', null),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _section(_chart(theme, bars, average)),
            _section(_breakdown(theme, inPeriod, tasks, total)),
            if (_period == InsightPeriod.week)
              _section(_weekTimeline(theme, inPeriod, start)),
            _section(_hours(theme, inPeriod)),
            _section(_yearGrid(theme, sessions, start.year)),
            _section(_records(theme, inPeriod, tasks)),
          ],
        ),
      ),
    );
  }

  /// ("↑ 40m vs last week", colour) — colour null means neutral.
  (String, Color?) _trend(int diff, String Function(int) fmt) {
    final theme = Theme.of(context);
    if (diff == 0) return ('Same as last $_unit', null);
    return (
      '${diff > 0 ? '↑' : '↓'} ${fmt(diff.abs())} vs last $_unit',
      diff > 0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
    );
  }

  List<_Bar> _bars(
    List<FocusSession> sessions,
    DateTime start,
    DateTime end,
    DateTime today,
  ) {
    int minutes(DateTime a, DateTime b) =>
        totalMinutes(sessionsIn(sessions, a, b));
    switch (_period) {
      case InsightPeriod.week:
        return [
          for (var i = 0; i < 7; i++)
            () {
              final d = addDays(start, i);
              return _Bar(
                DateFormat('E').format(d).substring(0, 1),
                minutes(d, addDays(d, 1)),
                current: d == today,
                future: d.isAfter(today),
              );
            }(),
        ];
      case InsightPeriod.month:
        final out = <_Bar>[];
        var i = 1;
        for (var w = start; w.isBefore(end); w = addDays(w, 7), i++) {
          final we = addDays(w, 7).isAfter(end) ? end : addDays(w, 7);
          out.add(
            _Bar(
              'W$i',
              minutes(w, we),
              current: !today.isBefore(w) && today.isBefore(we),
              future: w.isAfter(today),
            ),
          );
        }
        return out;
      case InsightPeriod.year:
        return [
          for (var m = 1; m <= 12; m++)
            _Bar(
              DateFormat('MMMMM').format(DateTime(start.year, m)),
              minutes(DateTime(start.year, m), DateTime(start.year, m + 1)),
              current: start.year == today.year && m == today.month,
              future: DateTime(start.year, m).isAfter(today),
            ),
        ];
    }
  }

  Widget _section(Widget child) =>
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), child: child);

  Widget _card(
    ThemeData theme,
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(16),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.colorScheme.outline),
    ),
    child: child,
  );

  Widget _cardTitle(ThemeData theme, String title, {String? trailing}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      );

  Widget _stat(
    ThemeData theme,
    String label,
    String value,
    (String, Color?) note,
  ) => _card(
    theme,
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 12,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          note.$1,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 12,
            color: note.$2 ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  Widget _chart(ThemeData theme, List<_Bar> bars, int average) {
    const chartHeight = 104.0;
    final maxMinutes = bars.fold<int>(
      0,
      (m, b) => b.minutes > m ? b.minutes : m,
    );
    final soft = theme.colorScheme.primary.withValues(alpha: 0.22);
    final heading = switch (_period) {
      InsightPeriod.week => 'Focus per day',
      InsightPeriod.month => 'Focus per week',
      InsightPeriod.year => 'Focus per month',
    };

    return _card(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(theme, heading, trailing: 'Avg ${formatMinutes(average)}'),
          Semantics(
            label: bars
                .where((b) => !b.future)
                .map((b) => '${b.label} ${formatMinutes(b.minutes)}')
                .join(', '),
            excludeSemantics: true,
            child: SizedBox(
              height: chartHeight + 36,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final b in bars)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: bars.length > 7 ? 3 : 5,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (b.minutes > 0 && bars.length <= 7)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  formatMinutes(b.minutes),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: b.current
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                              height: b.minutes == 0 || maxMinutes == 0
                                  ? 4
                                  : (b.minutes / maxMinutes * chartHeight)
                                        .clamp(4.0, chartHeight),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: b.current
                                    ? theme.colorScheme.primary
                                    : b.minutes > 0
                                    ? soft
                                    : theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              b.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: b.current
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant,
                                fontWeight: b.current
                                    ? FontWeight.w700
                                    : FontWeight.w500,
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
        ],
      ),
    );
  }

  Widget _breakdown(
    ThemeData theme,
    List<FocusSession> sessions,
    List<Task> tasks,
    int total,
  ) {
    final byId = {for (final t in tasks) t.id: t};
    final buckets = <String, int>{};
    var noTask = 0;
    for (final s in sessions) {
      final task = byId[s.linkedTaskId];
      if (s.linkedTaskId == null) {
        noTask += s.durationMinutes;
        continue;
      }
      final key = _byCategory
          ? (task?.category ?? 'Other')
          : (task?.title ?? 'Deleted task');
      buckets[key] = (buckets[key] ?? 0) + s.durationMinutes;
    }
    final sorted = buckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rows = <(String, int, bool)>[
      ...sorted.take(5).map((e) => (e.key, e.value, false)),
      if (sorted.length > 5)
        ('Other', sorted.skip(5).fold<int>(0, (s, e) => s + e.value), true),
      if (noTask > 0) ('No task', noTask, true),
    ];

    return _card(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(theme, 'Where the time went'),
          SegmentedControl<bool>(
            value: _byCategory,
            options: const {false: 'By task', true: 'By category'},
            onChanged: (v) => setState(() => _byCategory = v),
          ),
          const SizedBox(height: 16),
          if (rows.isEmpty)
            Text(
              'No focus sessions in this $_unit.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (final (name, minutes, quiet) in rows) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      color: quiet
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${formatMinutes(minutes)} · ${total == 0 ? 0 : (minutes * 100 / total).round()}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : minutes / total,
                minHeight: 6,
                backgroundColor: AppColors.of(context).raised,
                color: quiet
                    ? AppColors.of(context).ring
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  /// Seven columns, one per day; each session is a block placed by time of day.
  Widget _weekTimeline(
    ThemeData theme,
    List<FocusSession> sessions,
    DateTime monday,
  ) {
    const height = 200.0;
    var first = 8, last = 20; // hours shown; widened to fit the week's sessions
    for (final s in sessions) {
      final end = s.timestamp.add(Duration(minutes: s.durationMinutes));
      if (s.timestamp.hour < first) first = s.timestamp.hour;
      final endHour = end.day != s.timestamp.day
          ? 24
          : end.hour + (end.minute > 0 ? 1 : 0);
      if (endHour > last) last = endHour;
    }
    final span = (last - first) * 60;
    double y(DateTime t) => ((t.hour - first) * 60 + t.minute) / span * height;
    final labelHours = [first, (first + last) ~/ 2, last];

    return _card(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(
            theme,
            'Week timeline',
            trailing: '${sessions.length} sessions',
          ),
          SizedBox(
            height: height,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 36,
                  child: Stack(
                    children: [
                      for (final h in labelHours)
                        Positioned(
                          top: ((h - first) * 60 / span * height - 7).clamp(
                            0.0,
                            height - 14,
                          ),
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: AppColors.of(context).raised,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Stack(
                        children: [
                          for (final s in sessions.where(
                            (s) => DateUtils.isSameDay(
                              s.timestamp,
                              addDays(monday, i),
                            ),
                          ))
                            Positioned(
                              left: 2,
                              right: 2,
                              top: y(s.timestamp).clamp(0.0, height),
                              height: (s.durationMinutes / span * height).clamp(
                                3.0,
                                height,
                              ),
                              child: Tooltip(
                                message:
                                    '${DateFormat.Hm().format(s.timestamp)} · ${formatMinutes(s.durationMinutes)}',
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
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
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(width: 36),
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Text(
                    DateFormat('E').format(addDays(monday, i)).substring(0, 1),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hours(ThemeData theme, List<FocusSession> sessions) {
    final hours = minutesByHour(sessions);
    final max = hours.reduce((a, b) => a > b ? a : b);
    final peak = max == 0 ? null : hours.indexOf(max);
    const h = 72.0;
    return _card(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(
            theme,
            'Most focused time',
            trailing: peak == null
                ? null
                : 'Peak ${peak.toString().padLeft(2, '0')}:00 – ${(peak + 1).toString().padLeft(2, '0')}:00',
          ),
          Semantics(
            label: peak == null
                ? 'No focus yet'
                : 'Most focus between $peak and ${peak + 1} o\'clock',
            excludeSemantics: true,
            child: SizedBox(
              height: h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 24; i++)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        height: max == 0 || hours[i] == 0
                            ? 3
                            : (hours[i] / max * h).clamp(3.0, h),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i == peak
                              ? theme.colorScheme.primary
                              : hours[i] > 0
                              ? theme.colorScheme.primary.withValues(alpha: 0.3)
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final l in const ['00', '06', '12', '18', '24'])
                Text(
                  l,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// GitHub-style grid: one column per week, one cell per day, shade by focus minutes.
  Widget _yearGrid(ThemeData theme, List<FocusSession> sessions, int year) {
    final byDay = minutesByDayOfYear(sessions, year);
    final jan1 = DateTime(year);
    final dayCount = DateTime.utc(
      year + 1,
    ).difference(DateTime.utc(year)).inDays; // UTC: no DST hours
    final lead = jan1.weekday - 1;
    final weeks = ((lead + dayCount) / 7).ceil();
    final yearTotal = byDay.values.fold<int>(0, (a, b) => a + b);
    final primary = theme.colorScheme.primary;
    Color shade(int m) => m == 0
        ? AppColors.of(context).raised
        : m < 60
        ? primary.withValues(alpha: 0.25)
        : m < 120
        ? primary.withValues(alpha: 0.5)
        : m < 240
        ? primary.withValues(alpha: 0.75)
        : primary;
    const cell = 11.0, gap = 3.0;

    return _card(
      theme,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(
            theme,
            'Year grid · $year',
            trailing: '${byDay.length} days · ${formatMinutes(yearTotal)}',
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: year == DateTime.now().year, // open on the recent weeks
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var w = 0; w < weeks; w++)
                      SizedBox(
                        width: cell + gap,
                        child: () {
                          final firstDay = DateTime(year, 1, 1 + w * 7 - lead);
                          final showMonth =
                              firstDay.day <= 7 && firstDay.year == year;
                          return Text(
                            showMonth ? DateFormat('MMM').format(firstDay) : '',
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        }(),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var w = 0; w < weeks; w++)
                      Padding(
                        padding: const EdgeInsets.only(right: gap),
                        child: Column(
                          children: [
                            for (var d = 0; d < 7; d++)
                              () {
                                final idx = w * 7 + d - lead;
                                final inYear = idx >= 0 && idx < dayCount;
                                return Container(
                                  width: cell,
                                  height: cell,
                                  margin: const EdgeInsets.only(bottom: gap),
                                  decoration: BoxDecoration(
                                    color: inYear
                                        ? shade(byDay[idx] ?? 0)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(2.5),
                                  ),
                                );
                              }(),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              for (final m in const [0, 30, 90, 180, 300])
                Container(
                  width: cell,
                  height: cell,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: shade(m),
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              Text(
                'More',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _records(
    ThemeData theme,
    List<FocusSession> sessions,
    List<Task> tasks,
  ) {
    final sorted = [...sessions]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final byId = {for (final t in tasks) t.id: t};
    return _card(
      theme,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(
            theme,
            'Focus records',
            trailing: sorted.isEmpty ? null : 'Swipe to delete',
          ),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'No focus sessions in this $_unit.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final s in sorted.take(5))
            _recordRow(theme, s, byId[s.linkedTaskId]),
          if (sorted.length > 5)
            TextButton(
              onPressed: () => _showAllRecords(sorted, byId),
              child: Text('Show all ${sorted.length}'),
            ),
        ],
      ),
    );
  }

  Widget _recordRow(ThemeData theme, FocusSession s, Task? task) {
    final end = s.timestamp.add(Duration(minutes: s.durationMinutes));
    return Dismissible(
      key: ValueKey('record-${s.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 12),
        child: Icon(
          LucideIcons.trash2,
          size: 18,
          color: theme.colorScheme.error,
        ),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(focusSessionRepositoryProvider).deleteFocusSession(s.id);
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                LucideIcons.timer,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task?.title ??
                        (s.linkedTaskId == null ? 'No task' : 'Deleted task'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    '${DateFormat('EEE d MMM').format(s.timestamp)} · ${DateFormat.Hm().format(s.timestamp)}–${DateFormat.Hm().format(end)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatMinutes(s.durationMinutes),
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }

  void _showAllRecords(List<FocusSession> sorted, Map<String, Task> byId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'Focus records',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    for (final s in sorted)
                      _recordRow(theme, s, byId[s.linkedTaskId]),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddFocusRecordModal(BuildContext context, DateTime initialDate) {
    DateTime date = initialDate;
    final nowDateTime = DateTime.now();
    final startDefault = nowDateTime.subtract(const Duration(minutes: 45));
    TimeOfDay startTime = TimeOfDay(
      hour: startDefault.hour,
      minute: startDefault.minute,
    );
    TimeOfDay endTime = TimeOfDay.now();
    String? selectedTaskId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final theme = Theme.of(context);

            final startDateTime = DateTime(
              date.year,
              date.month,
              date.day,
              startTime.hour,
              startTime.minute,
            );
            var endDateTime = DateTime(
              date.year,
              date.month,
              date.day,
              endTime.hour,
              endTime.minute,
            );
            if (endDateTime.isBefore(startDateTime)) {
              endDateTime = endDateTime.add(const Duration(days: 1));
            }
            final durationMinutes = endDateTime
                .difference(startDateTime)
                .inMinutes;

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Log Focus Record',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            title: Text(
                              'Date: ${DateFormat.yMMMd().format(date)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            trailing: Icon(
                              LucideIcons.calendar,
                              color: theme.colorScheme.primary,
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setModalState(() => date = picked);
                              }
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: Text(
                              'Start Time: ${startTime.format(context)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            trailing: Icon(
                              LucideIcons.clock,
                              color: theme.colorScheme.primary,
                            ),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (picked != null) {
                                setModalState(() => startTime = picked);
                              }
                            },
                          ),
                          const Divider(height: 1),
                          ListTile(
                            title: Text(
                              'End Time: ${endTime.format(context)}',
                              style: theme.textTheme.bodyMedium,
                            ),
                            trailing: Icon(
                              LucideIcons.clock,
                              color: theme.colorScheme.primary,
                            ),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (picked != null) {
                                setModalState(() => endTime = picked);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Calculated Duration',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            durationMinutes > 0
                                ? '${durationMinutes ~/ 60 > 0 ? "${durationMinutes ~/ 60}h " : ""}${durationMinutes % 60}m ($durationMinutes min)'
                                : '0 min',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Link to Task (Optional)',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.2,
                          ),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          isExpanded: true,
                          value: selectedTaskId,
                          hint: Text(
                            'Select a task',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: const Text('None'),
                            ),
                            ...((ref.read(tasksStreamProvider).value ?? []).map(
                              (task) {
                                return DropdownMenuItem<String?>(
                                  value: task.id,
                                  child: Text(
                                    task.title,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            )),
                          ],
                          onChanged: (val) {
                            setModalState(() => selectedTaskId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: durationMinutes <= 0
                            ? null
                            : () {
                                final record = FocusSession(
                                  id: DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                                  durationMinutes: durationMinutes,
                                  timestamp: startDateTime,
                                  linkedTaskId: selectedTaskId,
                                );
                                ref
                                    .read(focusSessionRepositoryProvider)
                                    .addFocusSession(record);
                                Navigator.pop(context);
                              },
                        child: const Text(
                          'Save Focus Record',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
