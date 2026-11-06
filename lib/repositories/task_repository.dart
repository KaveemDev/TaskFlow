import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../services/notification_service.dart';

class TaskRepository {
  final CollectionReference _tasksCollection = FirebaseFirestore.instance
      .collection('tasks');

  TaskRepository();

  Stream<List<Task>> getTasks() {
    return _tasksCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Task.fromFirestore(doc)).toList();
    });
  }

  Future<void> addTask(Task task) async {
    await _tasksCollection.doc(task.id).set(task.toFirestore());
    await NotificationService().scheduleTaskNotification(task);
  }

  Future<void> updateTask(Task task) async {
    await _tasksCollection.doc(task.id).update(task.toFirestore());
    if (task.isCompleted) {
      await NotificationService().cancelNotification(task.id.hashCode);
    } else {
      await NotificationService().scheduleTaskNotification(task);
    }
  }

  Future<void> deleteTask(String id) async {
    await _tasksCollection.doc(id).delete();
    await NotificationService().cancelNotification(id.hashCode);
  }
}
