import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/event_model.dart';
import '../models/focus_session_model.dart';
import '../models/task_model.dart';
import '../providers/providers.dart';
import '../services/widget_service.dart';
import '../widgets/ui.dart';

/// Settings › Home screen widgets: what each widget shows and the options it has.
class WidgetSettingsScreen extends ConsumerStatefulWidget {
  const WidgetSettingsScreen({super.key});

  @override
  ConsumerState<WidgetSettingsScreen> createState() =>
      _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends ConsumerState<WidgetSettingsScreen> {
  String? _pinnedId;
  bool _hideName = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final hide = await WidgetService.getHideCountdownTaskName();
    if (!mounted) return;
    setState(() {
      _pinnedId = prefs.getString('pinned_countdown_id');
      _hideName = hide;
      _loaded = true;
    });
  }

  /// Pushes current data to every widget so a change shows up right away.
  Future<void> _refresh() async {
    final tasks = ref.read(tasksStreamProvider).value ?? const <Task>[];
    final sessions =
        ref.read(focusSessionsStreamProvider).value ?? const <FocusSession>[];
    final events = ref.read(eventsStreamProvider).value ?? const <Event>[];
    await WidgetService.updateWidget(tasks, sessions, events);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
    final events = ref.watch(eventsStreamProvider).value ?? const <Event>[];
    final now = DateTime.now();
    final candidates = WidgetService.countdownCandidates(tasks, events, now);
    final shown = WidgetService.pickCountdown(candidates, _pinnedId, now);
    final pinnedStillThere = candidates.any((c) => c.id == _pinnedId);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Back',
                  icon: const Icon(LucideIcons.chevronLeft),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            const ScreenHeader(
              subtitle: 'Choose what your home screen shows',
              title: 'Widgets',
            ),
            const SizedBox(height: 20),
            Padding(
              padding: kScreenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel('Countdown'),
                  _CountdownPreview(item: shown, hideName: _hideName),
                  const SizedBox(height: 8),
                  GroupedCard(
                    children: [
                      _row(
                        theme,
                        'Shows',
                        !_loaded
                            ? ''
                            : pinnedStillThere
                            ? shown!.title
                            : 'Next deadline',
                        onTap: () => _pickCountdown(candidates),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        title: Text(
                          'Hide task name',
                          style: theme.textTheme.titleMedium,
                        ),
                        subtitle: Text(
                          'Shows only the days left',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        value: _hideName,
                        onChanged: (v) async {
                          HapticFeedback.selectionClick();
                          setState(() => _hideName = v);
                          await WidgetService.setHideCountdownTaskName(v);
                          await _refresh();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionLabel('Other widgets'),
                  GroupedCard(
                    children: [
                      _info(
                        theme,
                        LucideIcons.chartColumn,
                        'Focus chart',
                        'Focus time per task for this week.',
                      ),
                      _info(
                        theme,
                        LucideIcons.zap,
                        'Quick actions',
                        'Open tasks, start a focus session or add a task.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Add widgets from your home screen: long-press an empty spot, then pick Kronom.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface,
                        backgroundColor: theme.colorScheme.surface,
                        side: BorderSide(color: theme.colorScheme.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: theme.textTheme.labelLarge,
                      ),
                      icon: const Icon(LucideIcons.refreshCw, size: 18),
                      label: const Text('Update widgets now'),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await _refresh();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Widgets updated'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
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

  Widget _row(
    ThemeData theme,
    String label,
    String value, {
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    child: SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Text(label, style: theme.textTheme.titleMedium),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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

  Widget _info(ThemeData theme, IconData icon, String title, String body) =>
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _pickCountdown(List<CountdownItem> candidates) async {
    const auto = '\u0000auto';
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        Widget tile(String id, String title, String? subtitle) => ListTile(
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
          trailing:
              (id == auto
                  ? _pinnedId == null ||
                        !candidates.any((c) => c.id == _pinnedId)
                  : id == _pinnedId)
              ? Icon(
                  LucideIcons.check,
                  size: 18,
                  color: theme.colorScheme.primary,
                )
              : null,
          onTap: () => Navigator.pop(ctx, id),
        );
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(
                  'Countdown shows',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 16),
                  children: [
                    tile(
                      auto,
                      'Next deadline',
                      'Switches to the next one automatically',
                    ),
                    for (final c in candidates)
                      tile(
                        c.id,
                        c.title,
                        '${DateFormat('EEE d MMM').format(c.targetDate)} · ${c.countdown(DateTime.now()).$1} ${c.countdown(DateTime.now()).$2}',
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    HapticFeedback.selectionClick();
    if (picked == auto) {
      await WidgetService.clearPinnedCountdown();
      setState(() => _pinnedId = null);
    } else {
      await WidgetService.pinToCountdownWidget(picked);
      setState(() => _pinnedId = picked);
    }
    await _refresh();
  }
}

/// In-app look of the countdown widget, so changes are visible before going to the home screen.
class _CountdownPreview extends StatelessWidget {
  const _CountdownPreview({required this.item, required this.hideName});
  final CountdownItem? item;
  final bool hideName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final (num, unit) = item?.countdown(now) ?? ('--', 'days left');
    final overdue = item != null && item!.daysLeft(now) < 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item?.label ?? 'UPCOMING DEADLINE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    letterSpacing: 0.6,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item == null
                      ? 'Nothing due'
                      : hideName
                      ? 'Upcoming deadline'
                      : item!.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEE d MMM').format(item!.targetDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                num,
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 44,
                  color: overdue
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ),
              Text(
                unit,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
