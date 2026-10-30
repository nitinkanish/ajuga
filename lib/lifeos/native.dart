import 'package:flutter/services.dart';

import 'reminders.dart';

const _channel = MethodChannel('aster/activity');

class LifeNative {
  static Future<Map<String, dynamic>> lifeSignals() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getLifeSignals');
      return Map<String, dynamic>.from(raw ?? {});
    } catch (_) {
      return {'healthStatus': 'unavailable', 'motionStatus': 'unavailable'};
    }
  }

  static Future<Map<String, dynamic>> requestCalendar() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('requestCalendarAccess');
      return Map<String, dynamic>.from(raw ?? {});
    } catch (_) {
      return {'status': 'unavailable'};
    }
  }

  static Future<List<Map<String, dynamic>>> todayEvents() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('todayEvents');
      final list = (raw?['events'] as List?) ?? [];
      return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<bool> requestNotifications() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('requestNotificationAuthorization');
      return raw?['granted'] == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> applyPlan(NotificationPlan? plan, {required String cancelId}) async {
    if (plan == null) {
      await cancel(cancelId);
      return;
    }
    try {
      await _channel.invokeMethod<void>('scheduleNotification', {
        'id': plan.id,
        'title': plan.title,
        'body': plan.body,
        'epochMs': plan.fireAt.millisecondsSinceEpoch,
        'repeatsWeekly': plan.repeatsWeekly,
        'hour': plan.fireAt.hour,
        'minute': plan.fireAt.minute,
        'weekday': plan.fireAt.weekday,
      });
    } catch (_) {}
  }

  static Future<void> cancel(String id) async {
    try {
      await _channel.invokeMethod<void>('cancelNotification', {'id': id});
    } catch (_) {}
  }
}
