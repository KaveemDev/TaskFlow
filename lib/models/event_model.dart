import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Event {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String? recurrenceRule;
  final String? colorHex;
  final int? notificationMinutesBefore;

  Event({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    this.recurrenceRule,
    this.colorHex,
    this.notificationMinutesBefore,
  });

  Event copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? recurrenceRule,
    String? colorHex,
    int? notificationMinutesBefore,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      colorHex: colorHex ?? this.colorHex,
      notificationMinutesBefore:
          notificationMinutesBefore ?? this.notificationMinutesBefore,
    );
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parseTime(dynamic val, DateTime fallback) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      return fallback;
    }

    return Event(
      id: doc.id,
      title: data['title'] ?? 'Event',
      description: data['description'],
      startTime: parseTime(data['startTime'], DateTime.now()),
      endTime: parseTime(
        data['endTime'],
        DateTime.now().add(const Duration(hours: 1)),
      ),
      recurrenceRule: data['recurrenceRule'],
      colorHex: data['colorHex'],
      notificationMinutesBefore: data['notificationMinutesBefore'] != null
          ? (data['notificationMinutesBefore'] as num).toInt()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      if (recurrenceRule != null) 'recurrenceRule': recurrenceRule,
      if (colorHex != null && colorHex!.isNotEmpty) 'colorHex': colorHex,
      if (notificationMinutesBefore != null)
        'notificationMinutesBefore': notificationMinutesBefore,
    };
  }

  Color? get color {
    if (colorHex == null || colorHex!.isEmpty) return null;
    try {
      String hex = colorHex!.replaceAll('#', '');
      if (hex.length == 6) {
        hex = 'FF$hex';
      }
      return Color(int.parse('0x$hex'));
    } catch (e) {
      return null;
    }
  }
}
