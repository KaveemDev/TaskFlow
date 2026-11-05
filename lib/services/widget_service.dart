import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import '../models/task_model.dart';
import '../models/focus_session_model.dart';
import '../models/event_model.dart';

/// A task or event the countdown widget can show.
class CountdownItem {
  final String id;
  final String title;
  final DateTime targetDate;
  final String label;

  CountdownItem({
    required this.id,
    required this.title,
    required this.targetDate,
    required this.label,
  });

  int daysLeft(DateTime now) => DateTime(
    targetDate.year,
    targetDate.month,
    targetDate.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;

  /// ("12", "days left"), ("0", "due today"), ("2", "days overdue")...
  (String, String) countdown(DateTime now) {
    final d = daysLeft(now);
    if (d < 0) return ('${-d}', -d == 1 ? 'day overdue' : 'days overdue');
    if (d == 0) return ('0', 'due today');
    return ('$d', d == 1 ? 'day left' : 'days left');
  }
}

class WidgetService {
  static Future<void> init() async {
    if (kIsWeb) return;
    await HomeWidget.setAppGroupId('group.com.example.taskflow_suite');
  }

  static Future<void> updateWidget(
    List<Task> tasks,
    List<FocusSession> sessions, [
    List<Event> events = const [],
  ]) async {
    if (kIsWeb) return;
    try {
      final activeTasksCount = tasks.where((t) => !t.isCompleted).length;
      await HomeWidget.saveWidgetData(
        'task_count_summary',
        '$activeTasksCount Active Tasks • + Tap to Add',
      );
      await HomeWidget.saveWidgetData('pomodoro_status', '25:00 Focus Ready');

      await _updateDeadlineWidgetData(tasks, events);

      await HomeWidget.renderFlutterWidget(
        _FocusDistributionWidget(tasks: tasks, sessions: sessions),
        logicalSize: const Size(800, 400),
        key: 'chart_image',
      );

      await HomeWidget.updateWidget(
        name: 'ProductivityWidgetProvider',
        androidName: 'ProductivityWidgetProvider',
        qualifiedAndroidName:
            'com.example.taskflow_suite.ProductivityWidgetProvider',
        iOSName: 'ProductivityWidget',
      );

      await HomeWidget.updateWidget(
        name: 'QuickActionWidgetProvider',
        androidName: 'QuickActionWidgetProvider',
        qualifiedAndroidName:
            'com.example.taskflow_suite.QuickActionWidgetProvider',
      );

      await HomeWidget.updateWidget(
        name: 'TaskDeadlineWidgetProvider',
        androidName: 'TaskDeadlineWidgetProvider',
        qualifiedAndroidName:
            'com.example.taskflow_suite.TaskDeadlineWidgetProvider',
      );
    } catch (e, stack) {
      debugPrint('WidgetService.updateWidget error: $e');
      debugPrintStack(stackTrace: stack, label: 'WidgetService.updateWidget');
      // Do NOT rethrow — caller in root_screen is fire-and-forget (no await/catch)
    }
  }

  static Future<void> pinToCountdownWidget(String itemId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pinned_countdown_id', itemId);
  }

  static Future<String?> getPinnedCountdownId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('pinned_countdown_id');
  }

  static Future<void> setHideCountdownTaskName(bool hide) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_countdown_task_name', hide);
    if (!kIsWeb) {
      await HomeWidget.saveWidgetData('hide_countdown_task_name', hide);
    }
  }

  static Future<bool> getHideCountdownTaskName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('hide_countdown_task_name') ?? false;
  }

  static String _getEmojiForTitle(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('birth') || lower.contains('bday')) return '🎂';
    if (lower.contains('party') || lower.contains('celebrat')) return '🎉';
    if (lower.contains('exam') ||
        lower.contains('test') ||
        lower.contains('study'))
      return '📚';
    if (lower.contains('flight') ||
        lower.contains('trip') ||
        lower.contains('travel') ||
        lower.contains('vacation'))
      return '✈️';
    if (lower.contains('gym') ||
        lower.contains('workout') ||
        lower.contains('fit'))
      return '💪';
    if (lower.contains('meet') || lower.contains('call')) return '💼';
    if (lower.contains('launch') ||
        lower.contains('release') ||
        lower.contains('deploy'))
      return '🚀';
    if (lower.contains('doctor') || lower.contains('health')) return '🏥';
    return '🎯';
  }

  static Future<void> clearPinnedCountdown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pinned_countdown_id');
  }

  /// Open tasks with a due date and events that have not ended, soonest first.
  static List<CountdownItem> countdownCandidates(
    List<Task> tasks,
    List<Event> events,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final items = <CountdownItem>[
      for (final t in tasks)
        if (!t.isCompleted && t.dueDate != null)
          CountdownItem(
            id: t.id,
            title: t.title,
            targetDate: t.dueDate!,
            label: t.category.isNotEmpty
                ? t.category.toUpperCase()
                : 'TASK DEADLINE',
          ),
      for (final e in events)
        if (!e.endTime.isBefore(today))
          CountdownItem(
            id: e.id,
            title: e.title,
            targetDate: e.startTime,
            label: 'CALENDAR EVENT',
          ),
    ];
    items.sort((a, b) => a.targetDate.compareTo(b.targetDate));
    return items;
  }

  /// The pinned item if it is still a candidate, otherwise the nearest one that is not overdue
  /// (or the nearest overdue one when nothing is upcoming).
  static CountdownItem? pickCountdown(
    List<CountdownItem> items,
    String? pinnedId,
    DateTime now,
  ) {
    if (items.isEmpty) return null;
    for (final i in items) {
      if (i.id == pinnedId) return i;
    }
    return items.firstWhere(
      (i) => i.daysLeft(now) >= 0,
      orElse: () => items.first,
    );
  }

  static Future<void> _updateDeadlineWidgetData(
    List<Task> tasks, [
    List<Event> events = const [],
  ]) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final selected = pickCountdown(
      countdownCandidates(tasks, events, now),
      prefs.getString('pinned_countdown_id'),
      now,
    );
    if (selected == null) {
      await HomeWidget.saveWidgetData('deadline_task_title', 'Scheduled Task');
      await HomeWidget.saveWidgetData('deadline_task_emoji', '🎯');
      await HomeWidget.saveWidgetData(
        'deadline_task_category',
        'UPCOMING DEADLINE',
      );
      await HomeWidget.saveWidgetData(
        'deadline_task_subtitle',
        'Tap to select task',
      );
      await HomeWidget.saveWidgetData('deadline_days_num', '--');
      await HomeWidget.saveWidgetData('deadline_days_unit', 'days left');
      return;
    }
    final (daysNum, daysUnit) = selected.countdown(now);

    final formattedDate = DateFormat('E, MMM d').format(selected.targetDate);
    final emoji = _getEmojiForTitle(selected.title);

    await HomeWidget.saveWidgetData('deadline_task_title', selected.title);
    await HomeWidget.saveWidgetData('deadline_task_emoji', emoji);
    await HomeWidget.saveWidgetData('deadline_task_category', selected.label);
    await HomeWidget.saveWidgetData('deadline_task_subtitle', formattedDate);
    await HomeWidget.saveWidgetData('deadline_days_num', daysNum);
    await HomeWidget.saveWidgetData('deadline_days_unit', daysUnit);
    final hideName = await getHideCountdownTaskName();
    await HomeWidget.saveWidgetData('hide_countdown_task_name', hideName);
  }

  static Future<void> updateQuickAction({
    required String pomodoroStatus,
    required int activeTasksCount,
  }) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData('pomodoro_status', pomodoroStatus);
      await HomeWidget.saveWidgetData(
        'task_count_summary',
        '$activeTasksCount Active Tasks • + Tap to Add',
      );
      await HomeWidget.updateWidget(
        name: 'QuickActionWidgetProvider',
        androidName: 'QuickActionWidgetProvider',
        qualifiedAndroidName:
            'com.example.taskflow_suite.QuickActionWidgetProvider',
      );
    } catch (e) {
      debugPrint('WidgetService.updateQuickAction error: $e');
    }
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Root widget rendered off-screen.
// RULES: no MaterialApp / Scaffold / ScaffoldMessenger / fl_chart.
//        Use only MediaQuery → Directionality → Material → CustomPaint.
// ──────────────────────────────────────────────────────────────────────────────
class _FocusDistributionWidget extends StatelessWidget {
  final List<Task> tasks;
  final List<FocusSession> sessions;

  const _FocusDistributionWidget({required this.tasks, required this.sessions});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Find start of current week (Monday)
    final weekdayOffset = (now.weekday - 1); // Mon=0
    final weekStart = todayStart.subtract(Duration(days: weekdayOffset));

    // Build task id → category map
    final taskCategory = <String, String>{};
    for (final t in tasks) {
      taskCategory[t.id] = t.category;
    }

    // Palette: category → color (assigned in order of first appearance)
    final palette = [
      const Color(0xFF6785FF),
      const Color(0xFFF08080),
      const Color(0xFFFFD56C),
      const Color(0xFFC780FF),
      const Color(0xFF7DE5C3),
    ];
    final categoryColors = <String, Color>{};
    Color colorFor(String cat) {
      return categoryColors.putIfAbsent(
        cat,
        () => palette[categoryColors.length % palette.length],
      );
    }

    // Aggregate sessions into: dayIndex (0=Mon … 6=Sun) → category → minutes
    final Map<int, Map<String, double>> dayData = {};
    int todayMinutes = 0;
    int weekMinutes = 0;

    for (final s in sessions) {
      final sDay = DateTime(
        s.timestamp.year,
        s.timestamp.month,
        s.timestamp.day,
      );
      final diffFromWeekStart = sDay.difference(weekStart).inDays;
      if (diffFromWeekStart < 0 || diffFromWeekStart > 6) continue;

      weekMinutes += s.durationMinutes;
      if (sDay == todayStart) todayMinutes += s.durationMinutes;

      final cat =
          (s.linkedTaskId != null && taskCategory.containsKey(s.linkedTaskId))
          ? taskCategory[s.linkedTaskId]!
          : 'Other';
      colorFor(cat); // register color in order

      dayData.putIfAbsent(diffFromWeekStart, () => {});
      dayData[diffFromWeekStart]![cat] =
          (dayData[diffFromWeekStart]![cat] ?? 0) + s.durationMinutes;
    }

    // If no sessions at all, ensure we still show something for the categories
    if (sessions.isEmpty) {
      for (final t in tasks) {
        colorFor(t.category);
      }
    }

    // Today / Week stat strings
    final todayH = todayMinutes ~/ 60;
    final todayM = todayMinutes % 60;
    final todayStr = todayH > 0
        ? (todayM > 0 ? '${todayH}h ${todayM}m' : '${todayH}h')
        : '${todayMinutes}m';

    final weekH = weekMinutes ~/ 60;
    final weekM = weekMinutes % 60;
    final weekStr = weekH > 0
        ? (weekM > 0 ? '${weekH}h ${weekM}m' : '${weekH}h')
        : '${weekMinutes}m';

    // Day labels Mon → Sun
    final dayLabels = List.generate(7, (i) {
      final d = weekStart.add(Duration(days: i));
      const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return names[d.weekday - 1];
    });

    // SizedBox is CRITICAL: home_widget's renderFlutterWidget uses
    // RenderPositionedBox (which loosens constraints) then a Column (which gives
    // children unbounded height). Without tight height, our inner Column's
    // Expanded(_BarChart) throws "RenderFlex children have non-zero flex but
    // incoming height constraints are unbounded" — caught & swallowed inside
    // renderFlutterWidget so chart_image is never written. The SizedBox forces
    // tight 800×400 constraints at our root, matching logicalSize.
    return SizedBox(
      width: 800,
      height: 400,
      child: MediaQuery(
        data: const MediaQueryData(size: Size(800, 400), devicePixelRatio: 1.0),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Roboto',
            decoration: TextDecoration.none,
          ),
          child: Directionality(
            textDirection: ui.TextDirection.ltr,
            child: Material(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(36),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      constraints.maxWidth * 0.035,
                      constraints.maxHeight * 0.06,
                      constraints.maxWidth * 0.035,
                      constraints.maxHeight * 0.05,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // LEFT: stats + chart
                        Expanded(
                          flex: 78,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Stats row
                              Row(
                                children: [
                                  _StatLabel(
                                    title: 'Today',
                                    value: todayStr,
                                    size: constraints,
                                  ),
                                  SizedBox(width: constraints.maxWidth * 0.07),
                                  _StatLabel(
                                    title: 'Week',
                                    value: weekStr,
                                    size: constraints,
                                  ),
                                ],
                              ),
                              SizedBox(height: constraints.maxHeight * 0.03),
                              // Chart
                              Expanded(
                                child: SizedBox.expand(
                                  child: _BarChart(
                                    dayData: dayData,
                                    categoryColors: categoryColors,
                                    dayLabels: dayLabels,
                                    todayIndex: weekdayOffset,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: constraints.maxWidth * 0.025),
                        // RIGHT: legend
                        Expanded(
                          flex: 22,
                          child: _Legend(
                            categoryColors: categoryColors,
                            size: constraints,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Stat block  (Today / Week)
// ──────────────────────────────────────────────────────────────────────────────
class _StatLabel extends StatelessWidget {
  final String title;
  final String value;
  final BoxConstraints size;
  const _StatLabel({
    required this.title,
    required this.value,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: const Color(0xFF9E9E9E),
            fontSize: size.maxHeight * 0.06,
            fontWeight: FontWeight.w400,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: size.maxHeight * 0.11,
            fontWeight: FontWeight.bold,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Legend
// ──────────────────────────────────────────────────────────────────────────────
class _Legend extends StatelessWidget {
  final Map<String, Color> categoryColors;
  final BoxConstraints size;
  const _Legend({required this.categoryColors, required this.size});

  @override
  Widget build(BuildContext context) {
    if (categoryColors.isEmpty) {
      return Center(
        child: Text(
          'No data',
          style: TextStyle(
            color: const Color(0xFF9E9E9E),
            fontSize: size.maxHeight * 0.05,
          ),
        ),
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categoryColors.entries.map((e) {
        return Padding(
          padding: EdgeInsets.only(bottom: size.maxHeight * 0.04),
          child: Row(
            children: [
              Container(
                width: size.maxHeight * 0.045,
                height: size.maxHeight * 0.045,
                decoration: BoxDecoration(
                  color: e.value,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: size.maxWidth * 0.02),
              Expanded(
                child: Text(
                  e.key,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size.maxHeight * 0.06,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Bar chart (pure CustomPaint – no fl_chart)
// ──────────────────────────────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final Map<int, Map<String, double>> dayData;
  final Map<String, Color> categoryColors;
  final List<String> dayLabels;
  final int todayIndex;

  const _BarChart({
    required this.dayData,
    required this.categoryColors,
    required this.dayLabels,
    required this.todayIndex,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
        dayData: dayData,
        categoryColors: categoryColors,
        dayLabels: dayLabels,
        todayIndex: todayIndex,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final Map<int, Map<String, double>> dayData;
  final Map<String, Color> categoryColors;
  final List<String> dayLabels;
  final int todayIndex;

  _ChartPainter({
    required this.dayData,
    required this.categoryColors,
    required this.dayLabels,
    required this.todayIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const xLabelH = 22.0; // height reserved for day labels
    const yLabelW = 32.0; // width reserved for hour labels

    final chartH = size.height - xLabelH;
    final chartW = size.width - yLabelW;

    // ── find max minutes ─────────────────────────────────────────────────────
    double maxMin = 0;
    for (final day in dayData.values) {
      final total = day.values.fold(0.0, (a, b) => a + b);
      if (total > maxMin) maxMin = total;
    }
    double maxMinutes = maxMin <= 0 ? 240 : maxMin * 1.25; // at least 4 h
    final maxHours = (maxMinutes / 60).ceil();
    int stepH = 2;
    if (maxHours > 6) stepH = 4;
    if (maxHours > 16) stepH = 8;
    final topH = ((maxHours / stepH).ceil() * stepH).clamp(stepH, 999);
    maxMinutes = topH * 60.0;

    // ── grid & y-axis labels ─────────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = size.height * 0.0035
      ..style = PaintingStyle.stroke;

    final steps = topH ~/ stepH;
    for (int i = 0; i <= steps; i++) {
      final y = chartH - (chartH * i / steps);
      _drawDashedLine(
        canvas,
        Offset(yLabelW, y),
        Offset(size.width, y),
        gridPaint,
      );

      final hours = i * stepH;
      final label = hours == 0 ? '0m' : '${hours}h';
      _drawText(
        canvas,
        label,
        Offset(0, y - (size.height * 0.035)),
        const Color(0xFF8E8E93),
        size.height * 0.0475,
        align: ui.TextAlign.right,
        maxWidth: yLabelW - 6,
      );
    }

    // ── bars ─────────────────────────────────────────────────────────────────
    final barSlot = chartW / 7;
    final barW = barSlot * 0.70;

    for (int dayIdx = 0; dayIdx < 7; dayIdx++) {
      final dayCounts = dayData[dayIdx] ?? {};
      final x = yLabelW + dayIdx * barSlot + (barSlot - barW) / 2;

      // Draw subtle background capsule track for every day slot
      final trackRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barW, chartH),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        trackRect,
        Paint()
          ..color = Colors.white.withValues(
            alpha: dayIdx == todayIndex ? 0.09 : 0.04,
          ),
      );

      final total = dayCounts.values.fold(0.0, (a, b) => a + b);

      if (dayCounts.isEmpty || total == 0) {
        // Subtle base pill indicator
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, chartH - 4, barW, 4),
          const Radius.circular(2),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = Colors.white.withValues(alpha: 0.15),
        );
      } else {
        double currentPx = 0;
        final entries = dayCounts.entries.toList();

        for (int ei = 0; ei < entries.length; ei++) {
          final cat = entries[ei].key;
          final val = entries[ei].value;
          final segH = (val / maxMinutes) * chartH;
          final color = categoryColors[cat] ?? Colors.grey;
          final isTop = ei == entries.length - 1;
          final isBottom = ei == 0;

          final rect = RRect.fromRectAndCorners(
            Rect.fromLTWH(x, chartH - currentPx - segH, barW, segH),
            topLeft: isTop ? const Radius.circular(6) : Radius.zero,
            topRight: isTop ? const Radius.circular(6) : Radius.zero,
            bottomLeft: isBottom ? const Radius.circular(6) : Radius.zero,
            bottomRight: isBottom ? const Radius.circular(6) : Radius.zero,
          );
          canvas.drawRRect(rect, Paint()..color = color);
          currentPx += segH;
        }
      }

      // Highlight today's day label
      final isToday = dayIdx == todayIndex;
      final labelColor = isToday ? Colors.white : const Color(0xFF8E8E93);
      _drawCenteredText(
        canvas,
        dayLabels[dayIdx],
        Offset(x + barW / 2, chartH + (size.height * 0.022)),
        labelColor,
        size.height * (isToday ? 0.056 : 0.051),
      );
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset centerOffset,
    Color color,
    double fontSize,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(centerOffset.dx - tp.width / 2, centerOffset.dy));
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashLen = 4.0;
    const gapLen = 4.0;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final dist = (end - start).distance;
    double drawn = 0;
    while (drawn < dist) {
      final segEnd = (drawn + dashLen).clamp(0, dist);
      final t0 = drawn / dist;
      final t1 = segEnd / dist;
      canvas.drawLine(
        Offset(start.dx + dx * t0, start.dy + dy * t0),
        Offset(start.dx + dx * t1, start.dy + dy * t1),
        paint,
      );
      drawn += dashLen + gapLen;
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double fontSize, {
    ui.TextAlign align = ui.TextAlign.left,
    double maxWidth = 200,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_ChartPainter old) => true;
}
