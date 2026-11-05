import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/focus_session_model.dart';

class FocusSessionRepository {
  final CollectionReference _sessionsCollection = FirebaseFirestore.instance
      .collection('focus_sessions');

  FocusSessionRepository();

  Stream<List<FocusSession>> getFocusSessions() {
    return _sessionsCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => FocusSession.fromFirestore(doc))
          .toList();
    });
  }

  Future<void> addFocusSession(FocusSession session) async {
    if (session.id.isEmpty) {
      await _sessionsCollection.add(session.toFirestore());
    } else {
      await _sessionsCollection.doc(session.id).set(session.toFirestore());
    }
  }

  Future<void> deleteFocusSession(String id) async {
    await _sessionsCollection.doc(id).delete();
  }
}
