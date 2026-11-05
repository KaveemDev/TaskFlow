import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/task_repository.dart';
import '../repositories/event_repository.dart';
import '../repositories/focus_session_repository.dart';
import '../models/task_model.dart';
import '../models/event_model.dart';
import '../models/focus_session_model.dart';

export 'navigation_provider.dart';
export 'timer_provider.dart';
export 'categories_provider.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(),
);
final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(),
);
final focusSessionRepositoryProvider = Provider<FocusSessionRepository>(
  (ref) => FocusSessionRepository(),
);

final tasksStreamProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).getTasks();
});

final eventsStreamProvider = StreamProvider<List<Event>>((ref) {
  return ref.watch(eventRepositoryProvider).getEvents();
});

final focusSessionsStreamProvider = StreamProvider<List<FocusSession>>((ref) {
  return ref.watch(focusSessionRepositoryProvider).getFocusSessions();
});
