import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

@immutable
class EventModel {
  const EventModel({
    required this.id,
    required this.title,
    required this.startDateTime,
    required this.endDateTime,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.location,
    this.isAllDay = false,
    this.color = 0xFF1B5E20,
    this.recurrenceRule,
    this.reminderMinutesBefore,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String? location;
  final bool isAllDay;
  final int color;
  final String? recurrenceRule;
  final int? reminderMinutesBefore;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory EventModel.fromRow(EventRow row) => EventModel(
        id: row.id,
        title: row.title,
        description: row.description,
        startDateTime: row.startDateTime,
        endDateTime: row.endDateTime,
        location: row.location,
        isAllDay: row.isAllDay,
        color: row.color,
        recurrenceRule: row.recurrenceRule,
        reminderMinutesBefore: row.reminderMinutesBefore,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      );

  EventsCompanion toCompanion() => EventsCompanion(
        id: Value<String>(id),
        title: Value<String>(title),
        description: Value<String?>(description),
        startDateTime: Value<DateTime>(startDateTime),
        endDateTime: Value<DateTime>(endDateTime),
        location: Value<String?>(location),
        isAllDay: Value<bool>(isAllDay),
        color: Value<int>(color),
        recurrenceRule: Value<String?>(recurrenceRule),
        reminderMinutesBefore: Value<int?>(reminderMinutesBefore),
        createdAt: Value<DateTime>(createdAt),
        updatedAt: Value<DateTime>(updatedAt),
      );

  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startDateTime,
    DateTime? endDateTime,
    String? location,
    bool? isAllDay,
    int? color,
    String? recurrenceRule,
    int? reminderMinutesBefore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      EventModel(
        id: id ?? this.id,
        title: title ?? this.title,
        description: description ?? this.description,
        startDateTime: startDateTime ?? this.startDateTime,
        endDateTime: endDateTime ?? this.endDateTime,
        location: location ?? this.location,
        isAllDay: isAllDay ?? this.isAllDay,
        color: color ?? this.color,
        recurrenceRule: recurrenceRule ?? this.recurrenceRule,
        reminderMinutesBefore: reminderMinutesBefore ?? this.reminderMinutesBefore,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
