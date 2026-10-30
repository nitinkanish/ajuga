import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ActivityTargets {
  ActivityTargets({
    this.steps = 8000,
    this.distanceMeters = 5000,
    this.exerciseMinutes = 30,
  });

  int steps;
  double distanceMeters;
  double exerciseMinutes;

  static const _key = 'aster.activity.targets.v1';

  Map<String, dynamic> toJson() => {
    'steps': steps,
    'distanceMeters': distanceMeters,
    'exerciseMinutes': exerciseMinutes,
  };

  factory ActivityTargets.fromJson(Map<String, dynamic> json) {
    return ActivityTargets(
      steps: (json['steps'] as num?)?.round() ?? 8000,
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 5000,
      exerciseMinutes: (json['exerciseMinutes'] as num?)?.toDouble() ?? 30,
    );
  }

  static Future<ActivityTargets> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return ActivityTargets();
    try {
      return ActivityTargets.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      return ActivityTargets();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}
