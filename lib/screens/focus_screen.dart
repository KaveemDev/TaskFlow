import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/providers.dart';
import '../models/task_model.dart';
import '../widgets/segmented_control.dart';
import '../widgets/ui.dart';

class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timer = ref.watch(timerProvider);
    final notifier = ref.read(timerProvider.notifier);
    final tasks = (ref.watch(tasksStreamProvider).value ?? const <Task>[])
        .where((t) => !t.isCompleted)
        .toList();
    final sessions = ref.watch(focusSessionsStreamProvider).value ?? const [];

    final now = DateTime.now();
    final today = sessions
        .where((s) => DateUtils.isSameDay(s.timestamp, now))
        .toList();
    final minutesToday = today.fold<int>(
      0,
      (sum, s) => sum + s.durationMinutes,
    );
    final doneInRound = today.length % kSessionsPerRound;
    final sessionNumber = doneInRound + 1;

    final total = timer.initialDurationMinutes * 60;
    final progress = total == 0
        ? 0.0
        : (1 - timer.remainingSeconds / total).clamp(0.0, 1.0);
    final mm = (timer.remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final ss = (timer.remainingSeconds % 60).toString().padLeft(2, '0');
    final selected = tasks
        .where((t) => t.id == timer.selectedTaskId)
        .firstOrNull;
    final paused = !timer.isRunning && timer.remainingSeconds < total;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            ScreenHeader(
              subtitle:
                  '${timer.mode == TimerMode.focus ? 'Session $sessionNumber of $kSessionsPerRound' : timer.mode.label} · ${formatMinutes(minutesToday)} today',
              title: 'Focus',
            ),
            const SizedBox(height: 24),
            Padding(
              padding: kScreenPadding,
              child: IgnorePointer(
                ignoring: timer.isRunning,
                child: Opacity(
                  opacity: timer.isRunning ? 0.6 : 1,
                  child: SegmentedControl<TimerMode>(
                    value: timer.mode,
                    options: {for (final m in TimerMode.values) m: m.label},
                    onChanged: notifier.setMode,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Semantics(
                      label: '${(progress * 100).round()} percent done',
                      child: CustomPaint(
                        size: const Size.square(280),
                        painter: _RingPainter(
                          progress: progress,
                          track: theme.colorScheme.outline,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap:
                          timer.isRunning ||
                              paused ||
                              timer.mode != TimerMode.focus
                          ? null
                          : () => _pickLength(
                              context,
                              ref,
                              timer.initialDurationMinutes,
                            ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$mm:$ss', style: theme.textTheme.displayLarge),
                          const SizedBox(height: 6),
                          Text(
                            timer.isRunning
                                ? 'of ${timer.initialDurationMinutes} min'
                                : paused
                                ? 'Paused'
                                : 'of ${timer.initialDurationMinutes} min',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: kScreenPadding,
              child: Material(
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: theme.colorScheme.outline),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      _pickTask(context, ref, tasks, timer.selectedTaskId),
                  child: SizedBox(
                    height: 60,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              LucideIcons.circleCheck,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Working on',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selected?.title ?? 'No task',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            LucideIcons.chevronDown,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundButton(
                  size: 52,
                  icon: LucideIcons.rotateCcw,
                  label: 'Reset timer',
                  onTap: notifier.reset,
                ),
                const SizedBox(width: 28),
                _RoundButton(
                  size: 76,
                  filled: true,
                  icon: timer.isRunning ? LucideIcons.pause : LucideIcons.play,
                  label: timer.isRunning ? 'Pause' : 'Start',
                  onTap: timer.isRunning ? notifier.pause : notifier.start,
                ),
                const SizedBox(width: 28),
                _RoundButton(
                  size: 52,
                  icon: LucideIcons.skipForward,
                  label: timer.mode == TimerMode.focus
                      ? 'Skip to break'
                      : 'Skip break',
                  onTap: notifier.skip,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Semantics(
              label:
                  '$doneInRound of $kSessionsPerRound sessions done this round',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < kSessionsPerRound; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == doneInRound && timer.mode == TimerMode.focus
                          ? 24
                          : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color:
                            i <=
                                doneInRound -
                                    (timer.mode == TimerMode.focus ? 0 : 1)
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLength(
    BuildContext context,
    WidgetRef ref,
    int current,
  ) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Focus length',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              for (final m in const [15, 25, 50, 90])
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text('$m min', style: theme.textTheme.titleMedium),
                  trailing: m == current
                      ? Icon(
                          LucideIcons.check,
                          size: 18,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(ctx, m),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (picked != null) ref.read(timerProvider.notifier).setDuration(picked);
  }

  void _pickTask(
    BuildContext context,
    WidgetRef ref,
    List<Task> tasks,
    String? selectedId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        Widget tile(
          String title,
          String? subtitle,
          bool selected,
          VoidCallback onTap,
        ) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(title, style: theme.textTheme.titleMedium),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
          trailing: selected
              ? Icon(
                  LucideIcons.check,
                  size: 18,
                  color: theme.colorScheme.primary,
                )
              : null,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
            Navigator.pop(ctx);
          },
        );
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text('Working on', style: theme.textTheme.headlineSmall),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    tile(
                      'No task',
                      null,
                      selectedId == null,
                      () => ref.read(timerProvider.notifier).selectTask(null),
                    ),
                    for (final t in tasks)
                      tile(
                        t.title,
                        t.category,
                        t.id == selectedId,
                        () => ref.read(timerProvider.notifier).selectTask(t.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final double size;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: Material(
        color: filled ? theme.colorScheme.primary : theme.colorScheme.surface,
        shape: CircleBorder(
          side: filled
              ? BorderSide.none
              : BorderSide(color: theme.colorScheme.outline),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: filled ? 28 : 20,
              color: filled
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
  });
  final double progress;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2 + 8);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base..color = track);
    if (progress > 0) {
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        base
          ..color = color
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}
