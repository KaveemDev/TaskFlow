import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/providers.dart';
import '../models/focus_session_model.dart';
import '../models/task_model.dart';
import '../models/event_model.dart';
import 'tasks_screen.dart';
import 'calendar_screen.dart';
import 'focus_screen.dart';
import 'insights_screen.dart';
import 'analytics_screen.dart';
import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'settings_screen.dart';
import '../services/widget_service.dart';
import '../services/notification_service.dart';

class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen>
    with WidgetsBindingObserver {
  final List<Widget> _screens = [
    const TasksScreen(),
    const CalendarScreen(),
    const FocusScreen(),
    const InsightsScreen(),
    const AnalyticsScreen(),
    const SettingsScreen(),
  ];

  List<Task> _latestTasks = [];
  List<FocusSession> _latestSessions = [];
  List<Event> _latestEvents = [];
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService().clearDeliveredNotifications();
    _listenToWidgetClicks();
  }

  void _listenToWidgetClicks() {
    // Cold launch from widget click
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null) {
        _handleWidgetClick(uri);
      }
    });

    // Warm launch/resume from widget click
    _widgetClickSub = HomeWidget.widgetClicked.listen((uri) {
      if (uri != null) {
        _handleWidgetClick(uri);
      }
    });
  }

  void _handleWidgetClick(Uri uri) {
    final uriStr = uri.toString();
    if (uri.host == 'insights' || uriStr.contains('insights')) {
      ref.read(navigationProvider.notifier).setIndex(3);
    } else if (uri.host == 'focus' || uriStr.contains('focus')) {
      ref.read(navigationProvider.notifier).setIndex(2);
    } else if (uri.host == 'add_task' || uriStr.contains('add_task')) {
      ref.read(navigationProvider.notifier).setIndex(0);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          showTaskModal(context, ref, null);
        }
      });
    } else if (uri.host == 'tasks' || uriStr.contains('tasks')) {
      ref.read(navigationProvider.notifier).setIndex(0);
    } else if (uri.host == 'calendar' ||
        uriStr.contains('calendar') ||
        uri.host == 'deadline' ||
        uriStr.contains('deadline')) {
      ref.read(navigationProvider.notifier).setIndex(1);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationService().clearDeliveredNotifications();
    }
  }

  void _refreshWidget() {
    WidgetService.updateWidget(_latestTasks, _latestSessions, _latestEvents);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);
    final theme = Theme.of(context);

    // Listen to tasks + focus sessions + events and refresh widget whenever any changes
    ref.listen(tasksStreamProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        _latestTasks = next.value!;
        _refreshWidget();
      }
    });

    ref.listen(focusSessionsStreamProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        _latestSessions = next.value!;
        _refreshWidget();
      }
    });

    ref.listen(eventsStreamProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        _latestEvents = next.value!;
        _refreshWidget();
      }
    });

    const tabs = [
      (0, LucideIcons.checkCircle2, 'Tasks'),
      (1, LucideIcons.calendar, 'Calendar'),
      (2, LucideIcons.timer, 'Focus'),
      (3, LucideIcons.barChart3, 'Insights'),
      (5, LucideIcons.slidersHorizontal, 'Settings'),
    ];

    return Scaffold(
      body: _screens[currentIndex]
          .animate(key: ValueKey(currentIndex))
          .fadeIn(duration: 200.ms, curve: Curves.easeOut),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.colorScheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                for (final (index, icon, label) in tabs)
                  Expanded(
                    child: _buildNavItem(
                      context,
                      currentIndex,
                      index,
                      icon,
                      label,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int currentIndex,
    int itemIndex,
    IconData icon,
    String label,
  ) {
    final isSelected = currentIndex == itemIndex;
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(navigationProvider.notifier).setIndex(itemIndex);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
