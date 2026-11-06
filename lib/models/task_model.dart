import 'package:cloud_firestore/cloud_firestore.dart';

class SubTask {
  final String id;
  final String title;
  final bool isCompleted;

  const SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
  });

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      isCompleted: map['isCompleted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'isCompleted': isCompleted};
  }

  SubTask copyWith({String? id, String? title, bool? isCompleted}) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class Task {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final String priority;
  final String category;
  final DateTime? dueDate;
  final DateTime? startTime;
  final DateTime? endTime;

  // Recurrence properties
  final String? repeatMode; // 'Daily', 'Weekly', 'Monthly', 'None'
  final DateTime? repeatEndDate;
  final String? parentTaskId;

  // Notification / Reminder option in minutes before start/due time
  // null or -1 indicates no notification
  final int? notificationMinutesBefore;
  final List<SubTask> subtasks;

  /// How long the task takes. With a start time it also sets [endTime], so the calendar can draw it.
  final int? durationMinutes;

  /// Stored duration, or the length of the start–end range for tasks saved before durations existed.
  int? get effectiveDurationMinutes =>
      durationMinutes ??
      (startTime != null && endTime != null
          ? endTime!.difference(startTime!).inMinutes
          : null);

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.isCompleted = false,
    this.priority = 'Low',
    this.category = 'General',
    this.dueDate,
    this.startTime,
    this.endTime,
    this.repeatMode,
    this.repeatEndDate,
    this.parentTaskId,
    this.notificationMinutesBefore = 0,
    this.subtasks = const [],
    this.durationMinutes,
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      priority: data['priority'] ?? 'Low',
      category: data['category'] ?? 'General',
      dueDate: data['dueDate'] != null
          ? (data['dueDate'] as Timestamp).toDate()
          : null,
      startTime: data['startTime'] != null
          ? (data['startTime'] as Timestamp).toDate()
          : null,
      endTime: data['endTime'] != null
          ? (data['endTime'] as Timestamp).toDate()
          : null,
      repeatMode: data['repeatMode'],
      repeatEndDate: data['repeatEndDate'] != null
          ? (data['repeatEndDate'] as Timestamp).toDate()
          : null,
      parentTaskId: data['parentTaskId'],
      notificationMinutesBefore: data['notificationMinutesBefore'] ?? 0,
      subtasks:
          (data['subtasks'] as List<dynamic>?)
              ?.map(
                (st) => SubTask.fromMap(Map<String, dynamic>.from(st as Map)),
              )
              .toList() ??
          const [],
      durationMinutes: (data['durationMinutes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'isCompleted': isCompleted,
      'priority': priority,
      'category': category,
      if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
      'startTime': startTime == null ? null : Timestamp.fromDate(startTime!),
      'endTime': endTime == null ? null : Timestamp.fromDate(endTime!),
      if (repeatMode != null) 'repeatMode': repeatMode,
      if (repeatEndDate != null)
        'repeatEndDate': Timestamp.fromDate(repeatEndDate!),
      if (parentTaskId != null) 'parentTaskId': parentTaskId,
      if (notificationMinutesBefore != null)
        'notificationMinutesBefore': notificationMinutesBefore,
      'subtasks': subtasks.map((st) => st.toMap()).toList(),
      'durationMinutes': durationMinutes,
    };
  }

  Task copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    String? priority,
    String? category,
    DateTime? dueDate,
    DateTime? startTime,
    DateTime? endTime,
    String? repeatMode,
    DateTime? repeatEndDate,
    String? parentTaskId,
    int? notificationMinutesBefore,
    List<SubTask>? subtasks,
    int? durationMinutes,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      dueDate: dueDate ?? this.dueDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      repeatMode: repeatMode ?? this.repeatMode,
      repeatEndDate: repeatEndDate ?? this.repeatEndDate,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      notificationMinutesBefore:
          notificationMinutesBefore ?? this.notificationMinutesBefore,
      subtasks: subtasks ?? this.subtasks,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}
