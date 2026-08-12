import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers.dart';
import '../models/focus_session_model.dart';

class TimerState {
  final int remainingSeconds;
  final bool isRunning;
  final int initialDurationMinutes;
  final String? selectedTaskId;
  final int? endTimeMs;
  final int? startTimeMs;

  TimerState({
    required this.remainingSeconds,
    required this.isRunning,
    required this.initialDurationMinutes,
    this.selectedTaskId,
    this.endTimeMs,
    this.startTimeMs,
  });

  TimerState copyWith({
    int? remainingSeconds,
    bool? isRunning,
    int? initialDurationMinutes,
    String? selectedTaskId,
    int? endTimeMs,
    int? startTimeMs,
  }) {
    return TimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isRunning: isRunning ?? this.isRunning,
      initialDurationMinutes: initialDurationMinutes ?? this.initialDurationMinutes,
      selectedTaskId: selectedTaskId ?? this.selectedTaskId,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      startTimeMs: startTimeMs ?? this.startTimeMs,
    );
  }
}

class TimerNotifier extends Notifier<TimerState> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  TimerState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
    });
    _loadState();
    return TimerState(remainingSeconds: 25 * 60, isRunning: false, initialDurationMinutes: 25);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncOnResume();
    }
  }

  void selectTask(String? taskId) async {
    state = state.copyWith(selectedTaskId: taskId);
    final prefs = await SharedPreferences.getInstance();
    if (taskId != null) {
      prefs.setString('timer_selected_task_id', taskId);
    } else {
      prefs.remove('timer_selected_task_id');
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final endTime = prefs.getInt('timer_end_time');
    final startTime = prefs.getInt('timer_start_time');
    final duration = prefs.getInt('timer_duration') ?? 25;
    final savedTaskId = prefs.getString('timer_selected_task_id');
    final taskId = (savedTaskId != null && savedTaskId.isNotEmpty) ? savedTaskId : state.selectedTaskId;
    
    if (endTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (endTime > now) {
        final remaining = ((endTime - now) / 1000).round();
        state = TimerState(
          remainingSeconds: remaining,
          isRunning: true,
          initialDurationMinutes: duration,
          selectedTaskId: taskId,
          endTimeMs: endTime,
          startTimeMs: startTime,
        );
        _startTimerTick();
      } else {
        prefs.remove('timer_end_time');
        prefs.remove('timer_start_time');
        prefs.remove('timer_selected_task_id');
        
        final sessionStartTime = startTime != null
            ? DateTime.fromMillisecondsSinceEpoch(startTime)
            : DateTime.fromMillisecondsSinceEpoch(endTime).subtract(Duration(minutes: duration));
            
        ref.read(focusSessionRepositoryProvider).addFocusSession(FocusSession(
          id: '',
          durationMinutes: duration,
          timestamp: sessionStartTime,
          linkedTaskId: taskId,
        ));
        
        state = TimerState(
          remainingSeconds: duration * 60,
          isRunning: false,
          initialDurationMinutes: duration,
          selectedTaskId: taskId,
        );
      }
    } else {
      state = state.copyWith(
        initialDurationMinutes: duration,
        remainingSeconds: duration * 60,
        selectedTaskId: taskId,
      );
    }
  }

  Future<void> _syncOnResume() async {
    if (!state.isRunning && state.endTimeMs == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final endTime = prefs.getInt('timer_end_time') ?? state.endTimeMs;
    final startTime = prefs.getInt('timer_start_time') ?? state.startTimeMs;
    final duration = prefs.getInt('timer_duration') ?? state.initialDurationMinutes;
    final taskId = state.selectedTaskId;

    if (endTime != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (endTime > now) {
        final remaining = ((endTime - now) / 1000).round();
        state = state.copyWith(
          remainingSeconds: remaining,
          isRunning: true,
          endTimeMs: endTime,
          startTimeMs: startTime,
        );
        _startTimerTick();
      } else {
        _timer?.cancel();
        prefs.remove('timer_end_time');
        prefs.remove('timer_start_time');
        prefs.remove('timer_selected_task_id');

        final sessionStartTime = startTime != null
            ? DateTime.fromMillisecondsSinceEpoch(startTime)
            : DateTime.fromMillisecondsSinceEpoch(endTime).subtract(Duration(minutes: duration));

        ref.read(focusSessionRepositoryProvider).addFocusSession(FocusSession(
          id: '',
          durationMinutes: duration,
          timestamp: sessionStartTime,
          linkedTaskId: taskId,
        ));

        state = TimerState(
          remainingSeconds: duration * 60,
          isRunning: false,
          initialDurationMinutes: duration,
          selectedTaskId: taskId,
        );
      }
    }
  }

  void setDuration(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('timer_duration', minutes);
    state = TimerState(
      remainingSeconds: minutes * 60,
      isRunning: false,
      initialDurationMinutes: minutes,
      selectedTaskId: state.selectedTaskId,
    );
    _timer?.cancel();
  }

  void start() async {
    if (state.isRunning || state.remainingSeconds <= 0) return;
    
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    
    // If resuming from a pause, adjust startTimeMs so that total elapsed time equals what has been run so far
    int startTimeMs = nowMs;
    if (state.remainingSeconds < state.initialDurationMinutes * 60) {
      final elapsedSecondsBeforePause = (state.initialDurationMinutes * 60) - state.remainingSeconds;
      startTimeMs = nowMs - (elapsedSecondsBeforePause * 1000);
    }
    
    final endTimeMs = nowMs + (state.remainingSeconds * 1000);
    prefs.setInt('timer_end_time', endTimeMs);
    prefs.setInt('timer_start_time', startTimeMs);
    prefs.setInt('timer_duration', state.initialDurationMinutes);
    if (state.selectedTaskId != null) {
      prefs.setString('timer_selected_task_id', state.selectedTaskId!);
    } else {
      prefs.remove('timer_selected_task_id');
    }
    
    state = state.copyWith(
      isRunning: true,
      endTimeMs: endTimeMs,
      startTimeMs: startTimeMs,
    );
    _startTimerTick();
  }

  void _startTimerTick() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!state.isRunning) {
        _timer?.cancel();
        return;
      }
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      if (state.endTimeMs != null) {
        final remaining = ((state.endTimeMs! - nowMs) / 1000).round();
        if (remaining > 0) {
          state = state.copyWith(remainingSeconds: remaining);
        } else {
          _timer?.cancel();
          state = state.copyWith(remainingSeconds: 0, isRunning: false);
          _onComplete();
        }
      } else if (state.remainingSeconds > 0) {
        state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
      } else {
        _timer?.cancel();
        state = state.copyWith(isRunning: false);
        _onComplete();
      }
    });
  }

  void addTime(int minutes) {
    if (state.remainingSeconds > 0) {
      final newRemaining = state.remainingSeconds + (minutes * 60);
      final newDuration = state.initialDurationMinutes + minutes;
      final newEndTimeMs = state.endTimeMs != null
          ? state.endTimeMs! + (minutes * 60 * 1000)
          : null;
      state = state.copyWith(
        remainingSeconds: newRemaining,
        initialDurationMinutes: newDuration,
        endTimeMs: newEndTimeMs,
      );
      _updatePrefsTime();
    }
  }

  void subtractTime(int minutes) {
    if (state.remainingSeconds > minutes * 60) {
      final newRemaining = state.remainingSeconds - (minutes * 60);
      final newDuration = state.initialDurationMinutes - minutes > 0
          ? state.initialDurationMinutes - minutes
          : 1;
      final newEndTimeMs = state.endTimeMs != null
          ? state.endTimeMs! - (minutes * 60 * 1000)
          : null;
      state = state.copyWith(
        remainingSeconds: newRemaining,
        initialDurationMinutes: newDuration,
        endTimeMs: newEndTimeMs,
      );
      _updatePrefsTime();
    } else if (state.remainingSeconds > 60) {
      final diffSeconds = state.remainingSeconds - 60;
      final newEndTimeMs = state.endTimeMs != null
          ? state.endTimeMs! - (diffSeconds * 1000)
          : null;
      state = state.copyWith(
        remainingSeconds: 60,
        endTimeMs: newEndTimeMs,
      );
      _updatePrefsTime();
    }
  }

  Future<void> _updatePrefsTime() async {
    final prefs = await SharedPreferences.getInstance();
    if (state.isRunning && state.endTimeMs != null) {
      prefs.setInt('timer_end_time', state.endTimeMs!);
    } else if (state.isRunning) {
      final endTime = DateTime.now().millisecondsSinceEpoch + (state.remainingSeconds * 1000);
      prefs.setInt('timer_end_time', endTime);
    }
    prefs.setInt('timer_duration', state.initialDurationMinutes);
  }

  void endEarly() {
    if (state.isRunning) {
      _timer?.cancel();
      state = state.copyWith(isRunning: false);
      
      int minutesSpent;
      if (state.startTimeMs != null) {
        final elapsedSeconds = ((DateTime.now().millisecondsSinceEpoch - state.startTimeMs!) / 1000).round();
        minutesSpent = (elapsedSeconds / 60).round();
      } else {
        minutesSpent = state.initialDurationMinutes - (state.remainingSeconds / 60).floor();
      }
      
      if (minutesSpent < 1) minutesSpent = 1; // Log at least 1 minute if they ended early but did something
      if (minutesSpent > state.initialDurationMinutes) {
        minutesSpent = state.initialDurationMinutes;
      }
      
      _onComplete(overrideMinutes: minutesSpent);
    }
  }

  void pause() async {
    _timer?.cancel();
    state = state.copyWith(isRunning: false, endTimeMs: null);
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('timer_end_time');
    prefs.remove('timer_start_time');
  }

  void reset() async {
    _timer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('timer_end_time');
    prefs.remove('timer_start_time');
    state = TimerState(
      remainingSeconds: state.initialDurationMinutes * 60,
      isRunning: false,
      initialDurationMinutes: state.initialDurationMinutes,
      selectedTaskId: state.selectedTaskId,
    );
  }

  void _onComplete({int? overrideMinutes}) async {
    final prefs = await SharedPreferences.getInstance();
    final startTimeMs = prefs.getInt('timer_start_time') ?? state.startTimeMs;
    prefs.remove('timer_end_time');
    prefs.remove('timer_start_time');
    
    final loggedMinutes = overrideMinutes ?? state.initialDurationMinutes;
    final sessionStartTime = startTimeMs != null
        ? DateTime.fromMillisecondsSinceEpoch(startTimeMs)
        : DateTime.now().subtract(Duration(minutes: loggedMinutes));
    
    ref.read(focusSessionRepositoryProvider).addFocusSession(FocusSession(
      id: '',
      durationMinutes: loggedMinutes,
      timestamp: sessionStartTime,
      linkedTaskId: state.selectedTaskId,
    ));
    
    reset();
  }
}

final timerProvider = NotifierProvider<TimerNotifier, TimerState>(TimerNotifier.new);

