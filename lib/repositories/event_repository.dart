import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';
import '../services/notification_service.dart';

class EventRepository {
  final CollectionReference _eventsCollection = FirebaseFirestore.instance
      .collection('events');

  EventRepository();

  Stream<List<Event>> getEvents() {
    return _eventsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList();
    });
  }

  Future<void> addEvent(Event event) async {
    final String docId = event.id.isEmpty
        ? _eventsCollection.doc().id
        : event.id;
    final eventWithId = event.copyWith(id: docId);
    await _eventsCollection.doc(docId).set(eventWithId.toFirestore());
    await NotificationService().scheduleEventNotification(eventWithId);
  }

  Future<void> updateEvent(Event event) async {
    await _eventsCollection.doc(event.id).update(event.toFirestore());
    await NotificationService().scheduleEventNotification(event);
  }

  Future<void> deleteEvent(String id) async {
    await _eventsCollection.doc(id).delete();
    await NotificationService().cancelNotification(id.hashCode);
  }
}
