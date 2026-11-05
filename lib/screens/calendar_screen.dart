import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/ui.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';
import '../models/task_model.dart';
import '../models/event_model.dart';
import '../models/focus_session_model.dart';
import 'tasks_screen.dart'; // Import to use showTaskModal
import 'package:intl/intl.dart';
import '../widgets/premium/premium_button.dart';
import '../widgets/premium/premium_text_field.dart';
import '../widgets/premium/premium_card.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<dynamic> _getEventsForDay(
    DateTime day,
    List<Task> tasks,
    List<Event> events,
  ) {
    List<dynamic> dayItems = [];

    // Add tasks due or starting on this day
    dayItems.addAll(
      tasks.where((t) {
        if (t.startTime != null) {
          return DateUtils.isSameDay(t.startTime, day);
        } else if (t.dueDate != null) {
          return DateUtils.isSameDay(t.dueDate, day);
        }
        return false;
      }),
    );

    // Add events on this day
    dayItems.addAll(
      events.where((e) {
        return DateUtils.isSameDay(e.startTime, day) ||
            DateUtils.isSameDay(e.endTime, day) ||
            (e.startTime.isBefore(day) && e.endTime.isAfter(day));
      }),
    );

    // Sort items by time if available
    dayItems.sort((a, b) {
      DateTime? timeA = a is Task
          ? a.startTime ?? a.dueDate
          : (a as Event).startTime;
      DateTime? timeB = b is Task
          ? b.startTime ?? b.dueDate
          : (b as Event).startTime;
      if (timeA == null && timeB == null) return 0;
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      return timeA.compareTo(timeB);
    });

    return dayItems;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
    final events = ref.watch(eventsStreamProvider).value ?? const <Event>[];
    final sessions =
        ref.watch(focusSessionsStreamProvider).value ?? const <FocusSession>[];
    final day = _selectedDay ?? _focusedDay;
    final items = _getEventsForDay(day, tasks, events);
    final eventCount = items.whereType<Event>().length;
    final deadlineCount = items
        .whereType<Task>()
        .where((t) => !t.isCompleted && t.endTime == null)
        .length;
    final daySessions = sessions
        .where((s) => DateUtils.isSameDay(s.timestamp, day))
        .toList();

    void moveWeek(int weeks) => setState(() {
      _selectedDay = addDays(day, 7 * weeks);
      _focusedDay = _selectedDay!;
    });

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add event',
        onPressed: () => _showEventModal(context, ref, null),
        child: const Icon(LucideIcons.plus, size: 24),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              subtitle:
                  '${_plural(eventCount, 'event')} · ${_plural(deadlineCount, 'deadline')}',
              title: DateFormat('MMMM').format(day),
              actions: [
                SquareIconButton(
                  icon: LucideIcons.chevronLeft,
                  tooltip: 'Previous week',
                  onPressed: () => moveWeek(-1),
                ),
                SquareIconButton(
                  icon: LucideIcons.chevronRight,
                  tooltip: 'Next week',
                  onPressed: () => moveWeek(1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            WeekStrip(
              selected: day,
              onSelected: (d) => setState(() {
                _selectedDay = d;
                _focusedDay = d;
              }),
              hasItems: (d) => _getEventsForDay(d, tasks, events).isNotEmpty,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: items.isEmpty && daySessions.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing scheduled.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : _DayTimeline(
                      key: ValueKey(DateUtils.dateOnly(day)),
                      day: day,
                      items: items,
                      sessions: daySessions,
                      tasks: tasks,
                      onTap: (item) {
                        HapticFeedback.lightImpact();
                        if (item is Task) showTaskModal(context, ref, item);
                        if (item is Event) _showEventModal(context, ref, item);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  void _showEventModal(
    BuildContext context,
    WidgetRef ref,
    Event? existingEvent,
  ) {
    String title = existingEvent?.title ?? '';
    String description = existingEvent?.description ?? '';
    DateTime eventDate =
        existingEvent?.startTime ?? (_selectedDay ?? DateTime.now());
    TimeOfDay startTime = existingEvent != null
        ? TimeOfDay.fromDateTime(existingEvent.startTime)
        : TimeOfDay.now();
    TimeOfDay endTime = existingEvent != null
        ? TimeOfDay.fromDateTime(existingEvent.endTime)
        : TimeOfDay.now().replacing(hour: (TimeOfDay.now().hour + 1) % 24);
    String? selectedColorHex = existingEvent?.colorHex;
    int? selectedReminderMinutes = existingEvent?.notificationMinutesBefore;

    final List<Map<String, dynamic>> colorBlocks = [
      {'label': 'Indigo', 'hex': '#3f51b5', 'color': const Color(0xFF3f51b5)},
      {'label': 'Emerald', 'hex': '#33b679', 'color': const Color(0xFF33b679)},
      {'label': 'Ocean', 'hex': '#039be5', 'color': const Color(0xFF039be5)},
      {'label': 'Crimson', 'hex': '#d50000', 'color': const Color(0xFFd50000)},
      {
        'label': 'Royal Blue',
        'hex': '#4285f4',
        'color': const Color(0xFF4285f4),
      },
      {'label': 'Coral', 'hex': '#e67c73', 'color': const Color(0xFFe67c73)},
      {'label': 'Purple', 'hex': '#8e24aa', 'color': const Color(0xFF8e24aa)},
      {'label': 'Amber', 'hex': '#f4511e', 'color': const Color(0xFFf4511e)},
      {'label': 'Lavender', 'hex': '#b39ddb', 'color': const Color(0xFFb39ddb)},
      {'label': 'Teal', 'hex': '#00897b', 'color': const Color(0xFF00897b)},
    ];

    final List<Map<String, dynamic>> reminderOptions = [
      {'label': 'None', 'minutes': null},
      {'label': 'At event time', 'minutes': 0},
      {'label': '5 min before', 'minutes': 5},
      {'label': '10 min before', 'minutes': 10},
      {'label': '15 min before', 'minutes': 15},
      {'label': '30 min before', 'minutes': 30},
      {'label': '1 hr before', 'minutes': 60},
      {'label': '1 day before', 'minutes': 1440},
    ];

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
                          existingEvent == null ? 'Create Event' : 'Edit Event',
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
                    PremiumTextField(
                      hintText: 'Event Title',
                      controller: TextEditingController(text: title)
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: title.length),
                        ),
                      onChanged: (val) => title = val,
                    ),
                    const SizedBox(height: 12),
                    PremiumTextField(
                      hintText: 'Event Description (optional)',
                      controller: TextEditingController(text: description)
                        ..selection = TextSelection.fromPosition(
                          TextPosition(offset: description.length),
                        ),
                      onChanged: (val) => description = val,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Date & Time',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PremiumCard(
                      padding: const EdgeInsets.all(0),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              LucideIcons.calendar,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            title: Text(
                              DateFormat('E, MMM d, yyyy').format(eventDate),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: Icon(
                              LucideIcons.chevronRight,
                              size: 18,
                              color: theme.colorScheme.outline,
                            ),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: eventDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setModalState(() => eventDate = picked);
                              }
                            },
                          ),
                          Divider(
                            height: 1,
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  title: Text(
                                    'Start: ${startTime.format(context)}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  trailing: Icon(
                                    LucideIcons.clock,
                                    size: 20,
                                    color: theme.colorScheme.outline,
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
                              ),
                              Container(
                                height: 30,
                                width: 1,
                                color: theme.colorScheme.outlineVariant,
                              ),
                              Expanded(
                                child: ListTile(
                                  title: Text(
                                    'End: ${endTime.format(context)}',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  trailing: Icon(
                                    LucideIcons.clock,
                                    size: 20,
                                    color: theme.colorScheme.outline,
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
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Color Block',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 48,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: colorBlocks.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final block = colorBlocks[idx];
                          final bool isSelected =
                              selectedColorHex == block['hex'];
                          final Color color = block['color'] as Color;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(
                                () => selectedColorHex = block['hex'] as String,
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: isSelected ? 44 : 38,
                              height: isSelected ? 44 : 38,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.onSurface
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(
                                      LucideIcons.check,
                                      color: Colors.white,
                                      size: 18,
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Icon(
                          LucideIcons.bellRing,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Reminder Notification',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: reminderOptions.map((opt) {
                        final bool isSelected =
                            selectedReminderMinutes == opt['minutes'];
                        return ChoiceChip(
                          label: Text(
                            opt['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.primary,
                          backgroundColor: theme
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                          onSelected: (selected) {
                            HapticFeedback.selectionClick();
                            setModalState(() {
                              selectedReminderMinutes = opt['minutes'] as int?;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    PremiumButton(
                      onPressed: () {
                        if (title.trim().isNotEmpty) {
                          final startDateTime = DateTime(
                            eventDate.year,
                            eventDate.month,
                            eventDate.day,
                            startTime.hour,
                            startTime.minute,
                          );
                          DateTime endDateTime = DateTime(
                            eventDate.year,
                            eventDate.month,
                            eventDate.day,
                            endTime.hour,
                            endTime.minute,
                          );
                          if (endDateTime.isBefore(startDateTime) ||
                              endDateTime.isAtSameMomentAs(startDateTime)) {
                            endDateTime = startDateTime.add(
                              const Duration(hours: 1),
                            );
                          }

                          final event = Event(
                            id:
                                existingEvent?.id != null &&
                                    existingEvent!.id.isNotEmpty
                                ? existingEvent.id
                                : DateTime.now().millisecondsSinceEpoch
                                      .toString(),
                            title: title.trim(),
                            description: description.trim().isEmpty
                                ? null
                                : description.trim(),
                            startTime: startDateTime,
                            endTime: endDateTime,
                            colorHex: selectedColorHex,
                            notificationMinutesBefore: selectedReminderMinutes,
                          );

                          if (existingEvent == null) {
                            ref.read(eventRepositoryProvider).addEvent(event);
                            setState(() {
                              _selectedDay = eventDate;
                              _focusedDay = eventDate;
                            });
                          } else {
                            ref
                                .read(eventRepositoryProvider)
                                .updateEvent(event);
                          }
                          Navigator.pop(context);

                          if (selectedReminderMinutes != null &&
                              selectedReminderMinutes != -1) {
                            final String reminderLabel =
                                selectedReminderMinutes == 0
                                ? 'at event time'
                                : '$selectedReminderMinutes minutes before';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.bellRing,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Reminder notification set ($reminderLabel)',
                                    ),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      label: existingEvent == null
                          ? 'Add Event'
                          : 'Save Changes',
                    ),
                    if (existingEvent != null) ...[
                      const SizedBox(height: 14),
                      PremiumButton(
                        isPrimary: false,
                        onPressed: () {
                          ref
                              .read(eventRepositoryProvider)
                              .deleteEvent(existingEvent.id);
                          Navigator.pop(context);
                        },
                        label: 'Delete Event',
                        icon: LucideIcons.trash2,
                      ),
                    ],
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

/// Hour grid for one day: events and timed tasks as blocks, untimed deadlines as pills,
/// focus sessions as blocks, and a now-line on today.
class _DayTimeline extends StatefulWidget {
  const _DayTimeline({
    super.key,
    required this.day,
    required this.items,
    required this.sessions,
    required this.tasks,
    required this.onTap,
  });

  final DateTime day;
  final List<dynamic> items;
  final List<FocusSession> sessions;
  final List<Task> tasks;
  final ValueChanged<dynamic> onTap;

  @override
  State<_DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<_DayTimeline> {
  static const _hourHeight = 58.0;
  static const _gutter = 50.0;
  late final ScrollController _scroll;
  late int _firstHour;
  late int _lastHour;

  @override
  void initState() {
    super.initState();
    final hours = <int>[];
    for (final i in widget.items) {
      final start = i is Event
          ? i.startTime
          : (i as Task).startTime ?? i.endTime;
      if (start != null && DateUtils.isSameDay(start, widget.day))
        hours.add(start.hour);
    }
    for (final s in widget.sessions) {
      hours.add(s.timestamp.hour);
    }
    _firstHour = hours.isEmpty
        ? 8
        : (hours.reduce((a, b) => a < b ? a : b)).clamp(0, 8);
    _lastHour = hours.isEmpty
        ? 18
        : (hours.reduce((a, b) => a > b ? a : b) + 1).clamp(18, 24);
    final now = DateTime.now();
    final focusHour = DateUtils.isSameDay(now, widget.day)
        ? now.hour - 1
        : (hours.isEmpty ? 9 : hours.first);
    _scroll = ScrollController(
      initialScrollOffset:
          ((focusHour - _firstHour).clamp(0, 24)) * _hourHeight,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  double _y(DateTime t) {
    final start = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _firstHour,
    );
    return t.difference(start).inMinutes * _hourHeight / 60;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final soft = theme.colorScheme.primaryContainer;
    final dayStart = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _firstHour,
    );
    final dayEnd = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
    ).add(Duration(hours: _lastHour));
    final height = (_lastHour - _firstHour) * _hourHeight;

    final untimed = widget.items
        .whereType<Task>()
        .where((t) => t.startTime == null && t.endTime == null)
        .toList();
    final children = <Widget>[];

    for (var h = _firstHour; h <= _lastHour; h++) {
      children.add(
        Positioned(
          left: 0,
          right: 0,
          top: (h - _firstHour) * _hourHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _gutter - 8,
                child: Transform.translate(
                  offset: const Offset(0, -7),
                  child: Text(
                    '${h.toString().padLeft(2, '0')}:00',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(height: 1, color: theme.colorScheme.outline),
              ),
            ],
          ),
        ),
      );
    }

    Widget block({
      required String title,
      required String subtitle,
      required Color bg,
      required Color dot,
      required DateTime start,
      required DateTime end,
      VoidCallback? onTap,
    }) {
      final s = start.isBefore(dayStart) ? dayStart : start;
      final e = end.isAfter(dayEnd) ? dayEnd : end;
      final h = (_y(e) - _y(s)).clamp(24.0, double.infinity) - 4;
      return Positioned(
        left: _gutter,
        right: 0,
        top: _y(s) + 2,
        height: h,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dot,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                  if (h > 40)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    String hm(DateTime t) => DateFormat.Hm().format(t);

    // shortcut: overlapping items are drawn on top of each other; add column packing if that gets common.
    for (final s in widget.sessions) {
      final end = s.timestamp.add(Duration(minutes: s.durationMinutes));
      final task = widget.tasks
          .where((t) => t.id == s.linkedTaskId)
          .firstOrNull;
      children.add(
        block(
          title: task == null ? 'Focus' : 'Focus · ${task.title}',
          subtitle: '${hm(s.timestamp)} – ${hm(end)}',
          bg: soft,
          dot: theme.colorScheme.primary,
          start: s.timestamp,
          end: end,
        ),
      );
    }

    for (final item in widget.items) {
      if (item is Event) {
        children.add(
          block(
            title: item.title,
            subtitle:
                '${hm(item.startTime)} – ${hm(item.endTime)}${(item.description ?? '').isNotEmpty ? ' · ${item.description}' : ''}',
            bg: soft,
            dot: item.color ?? theme.colorScheme.primary,
            start: item.startTime,
            end: item.endTime,
            onTap: () => widget.onTap(item),
          ),
        );
      } else if (item is Task &&
          item.startTime != null &&
          item.endTime != null) {
        children.add(
          block(
            title: item.title,
            subtitle:
                '${hm(item.startTime!)} – ${hm(item.endTime!)} · ${formatMinutes(item.effectiveDurationMinutes ?? 0)} · ${item.category}',
            bg: colors.raised,
            dot: theme.colorScheme.onSurfaceVariant,
            start: item.startTime!,
            end: item.endTime!,
            onTap: () => widget.onTap(item),
          ),
        );
      } else if (item is Task && (item.startTime ?? item.endTime) != null) {
        final at = (item.startTime ?? item.endTime)!;
        children.add(
          Positioned(
            left: _gutter,
            top: _y(at) - 14,
            child: _DeadlinePill(
              task: item,
              label: '${hm(at)} · ${item.title}',
              onTap: () => widget.onTap(item),
            ),
          ),
        );
      }
    }

    final now = DateTime.now();
    if (DateUtils.isSameDay(now, widget.day) &&
        now.isAfter(dayStart) &&
        now.isBefore(dayEnd)) {
      children.add(
        Positioned(
          left: _gutter - 8,
          right: 0,
          top: _y(now) - 4,
          child: IgnorePointer(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Container(height: 2, color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      children: [
        if (untimed.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: _gutter, bottom: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in untimed)
                  _DeadlinePill(
                    task: t,
                    label: t.effectiveDurationMinutes == null
                        ? t.title
                        : '${t.title} · ${formatMinutes(t.effectiveDurationMinutes!)}',
                    onTap: () => widget.onTap(t),
                  ),
              ],
            ),
          ),
        SizedBox(
          height: height + 8,
          child: Stack(clipBehavior: Clip.none, children: children),
        ),
      ],
    );
  }
}

class _DeadlinePill extends StatelessWidget {
  const _DeadlinePill({
    required this.task,
    required this.label,
    required this.onTap,
  });
  final Task task;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = task.isCompleted
        ? theme.colorScheme.onSurfaceVariant
        : AppColors.of(context).high;
    return Material(
      color: theme.colorScheme.surface,
      shape: StadiumBorder(side: BorderSide(color: theme.colorScheme.outline)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                task.isCompleted ? LucideIcons.check : LucideIcons.flag,
                size: 12,
                color: color,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
