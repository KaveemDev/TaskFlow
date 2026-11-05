import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/providers.dart';
import '../models/task_model.dart';
import '../theme/app_theme.dart';
import '../widgets/segmented_control.dart';
import '../widgets/ui.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  String? _category; // null = All
  bool _searching = false;
  String _query = '';
  bool _doneExpanded = false;

  bool _isToday(DateTime d) => DateUtils.isSameDay(d, DateTime.now());

  String _dayTitle(DateTime d) {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = DateUtils.dateOnly(d).difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    return DateFormat('EEEE').format(d);
  }

  bool _isOverdue(Task t, DateTime now) {
    if (t.isCompleted || t.dueDate == null) return false;
    final due = DateUtils.dateOnly(t.dueDate!);
    final today = DateUtils.dateOnly(now);
    if (due.isBefore(today)) return true;
    if (due == today) {
      final target = t.endTime ?? t.startTime;
      return target != null && target.isBefore(now);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final categories = ref.watch(categoriesProvider);
    if (_category != null && !categories.contains(_category)) _category = null;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add task',
        onPressed: () => showTaskModal(context, ref, null, initialDate: _day),
        child: const Icon(LucideIcons.plus, size: 24),
      ),
      body: SafeArea(
        bottom: false,
        child: tasksAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => Center(child: Text('Could not load tasks: $err')),
          data: (all) {
            final now = DateTime.now();
            bool matches(Task t) =>
                (_category == null || t.category == _category) &&
                (_query.isEmpty ||
                    t.title.toLowerCase().contains(_query.toLowerCase()));

            final onDay = all
                .where((t) {
                  if (t.dueDate == null)
                    return _isToday(_day); // undated tasks live on today
                  return DateUtils.isSameDay(t.dueDate, _day);
                })
                .where(matches)
                .toList();
            final overdue = _isToday(_day)
                ? all.where((t) => _isOverdue(t, now)).where(matches).toList()
                : <Task>[];
            final open =
                onDay
                    .where((t) => !t.isCompleted && !overdue.contains(t))
                    .toList()
                  ..sort(
                    (a, b) => (a.startTime ?? a.dueDate ?? now).compareTo(
                      b.startTime ?? b.dueDate ?? now,
                    ),
                  );
            final done = onDay.where((t) => t.isCompleted).toList();
            final total =
                onDay.length + overdue.where((t) => !onDay.contains(t)).length;

            return ListView(
              padding: const EdgeInsets.only(bottom: 104),
              children: [
                ScreenHeader(
                  subtitle:
                      '${DateFormat('EEEE, d MMMM').format(_day)} · ${done.length} of $total done',
                  title: _dayTitle(_day),
                  actions: [
                    SquareIconButton(
                      icon: _searching ? LucideIcons.x : LucideIcons.search,
                      tooltip: _searching ? 'Close search' : 'Search tasks',
                      onPressed: () => setState(() {
                        _searching = !_searching;
                        _query = '';
                      }),
                    ),
                  ],
                ),
                if (_searching)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: TextField(
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search tasks',
                        prefixIcon: Icon(LucideIcons.search, size: 18),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                WeekStrip(
                  selected: _day,
                  onSelected: (d) => setState(() => _day = d),
                ),
                const SizedBox(height: 18),
                _chips(theme, categories),
                const SizedBox(height: 20),
                if (overdue.isEmpty && open.isEmpty && done.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 64,
                      horizontal: 20,
                    ),
                    child: Text(
                      _query.isNotEmpty
                          ? 'No tasks match "$_query".'
                          : _isToday(_day)
                          ? 'No tasks for today.'
                          : 'No tasks on ${DateFormat('EEEE d MMMM').format(_day)}.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                if (overdue.isNotEmpty)
                  _section(
                    label: SectionLabel(
                      'Overdue · ${overdue.length}',
                      color: theme.colorScheme.error,
                    ),
                    tasks: overdue,
                    overdue: true,
                  ),
                if (open.isNotEmpty)
                  _section(
                    label: SectionLabel('${_dayTitle(_day)} · ${open.length}'),
                    tasks: open,
                  ),
                if (done.isNotEmpty) _doneSection(theme, done),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _chips(ThemeData theme, List<String> categories) {
    final items = <String?>[null, ...categories];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: kScreenPadding,
      child: Row(
        children: [
          for (final c in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _chip(theme, c),
            ),
        ],
      ),
    );
  }

  Widget _chip(ThemeData theme, String? c) {
    final selected = c == _category;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? theme.colorScheme.onSurface
            : theme.colorScheme.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected
                ? theme.colorScheme.onSurface
                : theme.colorScheme.outline,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _category = c);
          },
          onLongPress: c == null ? null : () => _confirmDeleteCategory(c),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(
              c ?? 'All',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: selected
                    ? theme.colorScheme.surface
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _section({
    required Widget label,
    required List<Task> tasks,
    bool overdue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          GroupedCard(
            children: [for (final t in tasks) _taskRow(t, overdue: overdue)],
          ),
        ],
      ),
    );
  }

  Widget _doneSection(ThemeData theme, List<Task> done) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: GroupedCard(
        children: [
          InkWell(
            onTap: () => setState(() => _doneExpanded = !_doneExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 15,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _doneExpanded ? 'Hide done tasks' : done.first.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w400,
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: _doneExpanded
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                  ),
                  Text(
                    'Done · ${done.length}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _doneExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      LucideIcons.chevronDown,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_doneExpanded)
            for (final t in done) _taskRow(t),
        ],
      ),
    );
  }

  String _meta(Task t, {required bool overdue}) {
    final parts = <String>[];
    if (overdue && t.dueDate != null) {
      final diff = DateUtils.dateOnly(
        DateTime.now(),
      ).difference(DateUtils.dateOnly(t.dueDate!)).inDays;
      final when = t.endTime ?? t.startTime;
      parts.add(
        diff == 0 && when != null
            ? DateFormat.Hm().format(when)
            : diff == 1
            ? 'Yesterday'
            : DateFormat('d MMM').format(t.dueDate!),
      );
    } else if (t.startTime != null) {
      parts.add(DateFormat.Hm().format(t.startTime!));
    }
    final d = t.effectiveDurationMinutes;
    if (d != null && d > 0) parts.add(formatMinutes(d));
    parts.add(t.category);
    if (t.subtasks.isNotEmpty) {
      parts.add(
        '${t.subtasks.where((s) => s.isCompleted).length} of ${t.subtasks.length} subtasks',
      );
    }
    if (t.repeatMode != null && t.repeatMode != 'None')
      parts.add(t.repeatMode!);
    return parts.join(' · ');
  }

  Widget _taskRow(Task task, {bool overdue = false}) {
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final hasPriority =
        !task.isCompleted &&
        const ['High', 'Medium', 'Low'].contains(task.priority);

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.error,
        child: Icon(LucideIcons.trash2, color: theme.colorScheme.onError),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        ref.read(taskRepositoryProvider).deleteTask(task.id);
      },
      child: InkWell(
        onTap: () => showTaskModal(context, ref, task),
        onLongPress: task.isCompleted
            ? null
            : () {
                // Long-press a task to start a focus session on it.
                HapticFeedback.mediumImpact();
                ref.read(timerProvider.notifier).selectTask(task.id);
                ref.read(navigationProvider.notifier).setIndex(2);
              },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 3, 16, 3),
          child: Row(
            children: [
              RoundCheck(
                checked: task.isCompleted,
                onChanged: () => _handleTaskCompletion(task),
              ),
              const SizedBox(width: 2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: task.isCompleted
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.onSurface,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _meta(task, overdue: overdue),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: overdue
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (hasPriority) ...[
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.flag,
                  size: 13,
                  color: colors.priority(task.priority),
                ),
                const SizedBox(width: 4),
                Text(
                  task.priority,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.priority(task.priority),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteCategory(String category) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$category"?'),
        content: const Text(
          'Tasks in this category stay, but keep the old category name.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () {
              ref.read(categoriesProvider.notifier).removeCategory(category);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _handleTaskCompletion(Task task) {
    HapticFeedback.lightImpact();
    bool completing = !task.isCompleted;

    if (completing && task.repeatMode != null && task.repeatMode != 'None') {
      DateTime nextDueDate = task.dueDate ?? DateTime.now();

      switch (task.repeatMode) {
        case 'Daily':
          nextDueDate = nextDueDate.add(const Duration(days: 1));
          break;
        case 'Weekly':
          nextDueDate = nextDueDate.add(const Duration(days: 7));
          break;
        case 'Monthly':
          nextDueDate = DateTime(
            nextDueDate.year,
            nextDueDate.month + 1,
            nextDueDate.day,
          );
          break;
      }

      bool shouldCreate = true;
      if (task.repeatEndDate != null &&
          nextDueDate.isAfter(task.repeatEndDate!)) {
        shouldCreate = false; // Past end date
      }

      if (shouldCreate) {
        DateTime? nextStartTime;
        DateTime? nextEndTime;
        if (task.startTime != null && task.dueDate != null) {
          nextStartTime = DateTime(
            nextDueDate.year,
            nextDueDate.month,
            nextDueDate.day,
            task.startTime!.hour,
            task.startTime!.minute,
          );
        }
        if (task.endTime != null && task.dueDate != null) {
          nextEndTime = DateTime(
            nextDueDate.year,
            nextDueDate.month,
            nextDueDate.day,
            task.endTime!.hour,
            task.endTime!.minute,
          );
        }

        final nextTask = Task(
          id: DateTime.now().millisecondsSinceEpoch.toString(), // new ID
          title: task.title,
          description: task.description,
          category: task.category,
          priority: task.priority,
          repeatMode: task.repeatMode,
          repeatEndDate: task.repeatEndDate,
          parentTaskId: task.parentTaskId ?? task.id,
          dueDate: nextDueDate,
          startTime: nextStartTime,
          endTime: nextEndTime,
          notificationMinutesBefore: task.notificationMinutesBefore,
          durationMinutes: task.durationMinutes,
          isCompleted: false,
        );
        ref.read(taskRepositoryProvider).addTask(nextTask);
      }
    }

    ref
        .read(taskRepositoryProvider)
        .updateTask(task.copyWith(isCompleted: completing));
  }
}

// ---------------------------------------------------------------------------
// New / edit task sheet
// ---------------------------------------------------------------------------

const _reminderOptions = <int, String>{
  -1: 'None',
  0: 'At start time',
  5: '5 min before',
  10: '10 min before',
  15: '15 min before',
  30: '30 min before',
  60: '1 hour before',
  1440: '1 day before',
};

void showTaskModal(
  BuildContext context,
  WidgetRef ref,
  Task? existingTask, {
  DateTime? initialDate,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        _TaskSheet(existingTask: existingTask, initialDate: initialDate),
  );
}

class _TaskSheet extends ConsumerStatefulWidget {
  const _TaskSheet({this.existingTask, this.initialDate});
  final Task? existingTask;
  final DateTime? initialDate;

  @override
  ConsumerState<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends ConsumerState<_TaskSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.existingTask?.title ?? '',
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existingTask?.description ?? '',
  );
  final TextEditingController _subtask = TextEditingController();

  late String _category = widget.existingTask?.category ?? 'Work';
  late String _priority = widget.existingTask?.priority ?? 'None';
  late String _repeat = widget.existingTask?.repeatMode ?? 'None';
  late DateTime? _repeatEnd = widget.existingTask?.repeatEndDate;
  late DateTime? _due = widget.existingTask?.dueDate ?? widget.initialDate;
  late TimeOfDay? _start = widget.existingTask?.startTime != null
      ? TimeOfDay.fromDateTime(widget.existingTask!.startTime!)
      : null;
  late int? _duration = widget.existingTask?.effectiveDurationMinutes;
  late int _reminder = widget.existingTask?.notificationMinutesBefore ?? 15;
  late final List<SubTask> _subtasks = List.of(
    widget.existingTask?.subtasks ?? const [],
  );

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _subtask.dispose();
    super.dispose();
  }

  String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String get _dueLabel {
    if (_due == null) return 'None';
    final diff = DateUtils.dateOnly(
      _due!,
    ).difference(DateUtils.dateOnly(DateTime.now())).inDays;
    final day = diff == 0
        ? 'Today'
        : diff == 1
        ? 'Tomorrow'
        : DateFormat('EEE d MMM').format(_due!);
    if (_start == null) return day;
    if (_duration == null) return '$day, ${_hm(_start!)}';
    final endMinutes = _start!.hour * 60 + _start!.minute + _duration!;
    final end = TimeOfDay(
      hour: (endMinutes ~/ 60) % 24,
      minute: endMinutes % 60,
    );
    return '$day, ${_hm(_start!)}–${_hm(end)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = ref.watch(categoriesProvider);
    if (!categories.contains(_category) && categories.isNotEmpty)
      _category = categories.first;
    final isEdit = widget.existingTask != null;
    final doneSubtasks = _subtasks.where((s) => s.isCompleted).length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 10, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit task' : 'New task',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  if (isEdit)
                    IconButton(
                      tooltip: 'Delete task',
                      icon: Icon(
                        LucideIcons.trash2,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      onPressed: () {
                        ref
                            .read(taskRepositoryProvider)
                            .deleteTask(widget.existingTask!.id);
                        Navigator.pop(context);
                      },
                    ),
                  IconButton(
                    tooltip: 'Close',
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  _bareField(
                    _title,
                    'Task title',
                    theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      letterSpacing: -0.2,
                    ),
                    autofocus: !isEdit,
                  ),
                  _bareField(
                    _notes,
                    'Add notes',
                    theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: null,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _propRow(
                          LucideIcons.calendar,
                          'Due',
                          _dueLabel,
                          valueColor: _due != null
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                          onTap: _pickWhen,
                        ),
                        const Divider(),
                        _propRow(
                          LucideIcons.hourglass,
                          'Duration',
                          _duration == null
                              ? 'None'
                              : formatMinutes(_duration!),
                          valueColor: _duration == null
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                          onTap: _pickDuration,
                        ),
                        const Divider(),
                        _propRow(
                          LucideIcons.tag,
                          'Category',
                          _category,
                          onTap: () => _pickCategory(categories),
                        ),
                        const Divider(),
                        _propRow(
                          LucideIcons.bell,
                          'Reminder',
                          _reminderOptions[_reminder] ??
                              '$_reminder min before',
                          onTap: _pickReminder,
                        ),
                        const Divider(),
                        _propRow(
                          LucideIcons.repeat,
                          'Repeat',
                          _repeat == 'None'
                              ? 'Never'
                              : _repeatEnd == null
                              ? _repeat
                              : '$_repeat until ${DateFormat('d MMM').format(_repeatEnd!)}',
                          valueColor: _repeat == 'None'
                              ? theme.colorScheme.onSurfaceVariant
                              : null,
                          onTap: _pickRepeat,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Priority',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedControl<String>(
                    value:
                        const [
                          'None',
                          'Low',
                          'Medium',
                          'High',
                        ].contains(_priority)
                        ? _priority
                        : 'None',
                    options: const {
                      'None': 'None',
                      'Low': 'Low',
                      'Medium': 'Medium',
                      'High': 'High',
                    },
                    onChanged: (p) => setState(() => _priority = p),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _subtasks.isEmpty
                        ? 'Subtasks'
                        : 'Subtasks · $doneSubtasks of ${_subtasks.length}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  for (final s in _subtasks)
                    Dismissible(
                      key: ValueKey(s.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (_) => setState(() => _subtasks.remove(s)),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          LucideIcons.trash2,
                          size: 18,
                          color: theme.colorScheme.error,
                        ),
                      ),
                      child: Row(
                        children: [
                          Transform.translate(
                            offset: const Offset(-10, 0),
                            child: RoundCheck(
                              square: true,
                              size: 20,
                              checked: s.isCompleted,
                              onChanged: () => setState(() {
                                final i = _subtasks.indexOf(s);
                                _subtasks[i] = s.copyWith(
                                  isCompleted: !s.isCompleted,
                                );
                              }),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              s.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: s.isCompleted
                                    ? theme.colorScheme.onSurfaceVariant
                                    : theme.colorScheme.onSurface,
                                decoration: s.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      Icon(
                        LucideIcons.plus,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _subtask,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addSubtask(),
                          style: theme.textTheme.bodyMedium,
                          decoration: const InputDecoration(
                            hintText: 'Add subtask',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _save,
                  child: Text(
                    isEdit ? 'Save' : 'Add task',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bareField(
    TextEditingController c,
    String hint,
    TextStyle? style, {
    bool autofocus = false,
    int? maxLines = 1,
  }) {
    return TextField(
      controller: c,
      autofocus: autofocus,
      maxLines: maxLines,
      style: style,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: style?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        filled: false,
        isDense: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
    );
  }

  Widget _propRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 50,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: theme.textTheme.titleMedium)),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: valueColor ?? theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSubtask() {
    final text = _subtask.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(
        SubTask(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: text,
        ),
      );
      _subtask.clear();
    });
  }

  Future<T?> _options<T>(String title, Map<T, String> options, T? current) {
    return showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(title, style: theme.textTheme.headlineSmall),
              ),
              for (final e in options.entries)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(e.value, style: theme.textTheme.titleMedium),
                  trailing: e.key == current
                      ? Icon(
                          LucideIcons.check,
                          size: 18,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, e.key),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickWhen() async {
    const pickDate = 'date', pickStart = 'start', clear = 'clear';
    final choice = await _options<String>('Due', {
      pickDate:
          'Date · ${_due == null ? 'None' : DateFormat('EEE d MMM').format(_due!)}',
      pickStart: 'Start time · ${_start == null ? 'None' : _hm(_start!)}',
      clear: 'Clear',
    }, null);
    if (!mounted || choice == null) return;
    switch (choice) {
      case pickDate:
        final d = await showDatePicker(
          context: context,
          initialDate: _due ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2035),
        );
        if (d != null) setState(() => _due = d);
      case pickStart:
        final t = await showTimePicker(
          context: context,
          initialTime: _start ?? TimeOfDay.now(),
        );
        if (t != null)
          setState(() {
            _start = t;
            _due ??= DateTime.now();
          });
      case clear:
        setState(() {
          _due = null;
          _start = null;
        });
    }
  }

  Future<void> _pickDuration() async {
    const none = -1;
    final picked = await _options<int>('Duration', {
      none: 'None',
      for (final m in const [15, 30, 45, 60, 90, 120, 180, 240])
        m: formatMinutes(m),
    }, _duration ?? none);
    if (picked != null)
      setState(() => _duration = picked == none ? null : picked);
  }

  Future<void> _pickCategory(List<String> categories) async {
    const newKey = '\u0000new';
    final picked = await _options<String>('Category', {
      for (final c in categories) c: c,
      newKey: 'New category…',
    }, _category);
    if (!mounted || picked == null) return;
    if (picked != newKey) {
      setState(() => _category = picked);
      return;
    }
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) {
      await ref.read(categoriesProvider.notifier).addCategory(name);
      if (mounted) setState(() => _category = name);
    }
  }

  Future<void> _pickReminder() async {
    final picked = await _options<int>('Reminder', _reminderOptions, _reminder);
    if (picked != null) setState(() => _reminder = picked);
  }

  Future<void> _pickRepeat() async {
    const endKey = '\u0000end';
    final picked = await _options<String>('Repeat', {
      'None': 'Never',
      'Daily': 'Daily',
      'Weekly': 'Weekly',
      'Monthly': 'Monthly',
      if (_repeat != 'None')
        endKey:
            'Ends · ${_repeatEnd == null ? 'Never' : DateFormat('d MMM y').format(_repeatEnd!)}',
    }, _repeat);
    if (!mounted || picked == null) return;
    if (picked == endKey) {
      final d = await showDatePicker(
        context: context,
        initialDate: _repeatEnd ?? DateTime.now().add(const Duration(days: 30)),
        firstDate: DateTime.now(),
        lastDate: DateTime(2035),
      );
      setState(() => _repeatEnd = d);
    } else {
      setState(() => _repeat = picked);
    }
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    _addSubtask(); // keep a typed-but-not-submitted subtask
    final existing = widget.existingTask;
    final due = _due ?? existing?.dueDate ?? DateTime.now();
    DateTime? at(TimeOfDay? t) => t == null
        ? null
        : DateTime(due.year, due.month, due.day, t.hour, t.minute);

    final task = Task(
      id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: _notes.text.trim(),
      isCompleted: existing?.isCompleted ?? false,
      category: _category,
      priority: _priority,
      repeatMode: _repeat,
      repeatEndDate: _repeatEnd,
      parentTaskId: existing?.parentTaskId,
      dueDate: due,
      startTime: at(_start),
      endTime: _start == null || _duration == null
          ? null
          : at(_start)!.add(Duration(minutes: _duration!)),
      durationMinutes: _duration,
      notificationMinutesBefore: _reminder,
      subtasks: _subtasks,
    );

    final repo = ref.read(taskRepositoryProvider);
    existing == null ? repo.addTask(task) : repo.updateTask(task);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (_reminder != -1 && _start != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Reminder set: ${_reminderOptions[_reminder] ?? '$_reminder min before'}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
