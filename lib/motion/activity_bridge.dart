import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'calculations.dart';

class DailyActivitySnapshot {
  const DailyActivitySnapshot({
    required this.dayStart,
    required this.updatedAt,
    required this.source,
    this.steps,
    this.distanceMeters,
    this.flights,
    this.exerciseMinutes,
    this.walkingSpeedMps,
    this.stepLengthMeters,
    this.walkingAsymmetry,
    this.doubleSupport,
  });

  final DateTime dayStart;
  final DateTime updatedAt;
  final String source;
  final int? steps;
  final double? distanceMeters;
  final double? flights;
  final double? exerciseMinutes;
  final double? walkingSpeedMps;
  final double? stepLengthMeters;
  final double? walkingAsymmetry;
  final double? doubleSupport;

  factory DailyActivitySnapshot.fromMap(Map<dynamic, dynamic> map) {
    final reconciled = reconcileDailyActivity(
      healthKitSteps: (map['hkSteps'] as num?)?.round(),
      healthKitDistanceMeters: (map['hkDistanceMeters'] as num?)?.toDouble(),
      pedometerSteps: map['cmSteps'] as int?,
      pedometerDistanceMeters: (map['cmDistanceMeters'] as num?)?.toDouble(),
    );
    return DailyActivitySnapshot(
      dayStart: DateTime.fromMillisecondsSinceEpoch(
        (map['dayStartEpochMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAtEpochMs'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      ),
      source: reconciled.source,
      steps: reconciled.steps ?? (map['steps'] as num?)?.round(),
      distanceMeters:
          reconciled.distanceMeters ?? (map['distanceMeters'] as num?)?.toDouble(),
      flights: (map['hkFlights'] as num?)?.toDouble(),
      exerciseMinutes: (map['hkExerciseMinutes'] as num?)?.toDouble(),
      walkingSpeedMps: (map['hkWalkingSpeedMps'] as num?)?.toDouble(),
      stepLengthMeters: (map['hkStepLengthMeters'] as num?)?.toDouble(),
      walkingAsymmetry: (map['hkWalkingAsymmetry'] as num?)?.toDouble(),
      doubleSupport: (map['hkDoubleSupport'] as num?)?.toDouble(),
    );
  }
}

class HistoryDay {
  const HistoryDay({required this.dayStart, required this.steps});

  final DateTime dayStart;
  final int steps;
}

class OutdoorPoint {
  OutdoorPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.horizontalAccuracy,
    this.speed,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitude;
  final double? horizontalAccuracy;
  final double? speed;

  Map<String, dynamic> toJson() => {
    'lat': latitude,
    'lon': longitude,
    't': timestamp.millisecondsSinceEpoch,
    'alt': altitude,
    'acc': horizontalAccuracy,
    'spd': speed,
  };

  factory OutdoorPoint.fromJson(Map<String, dynamic> json) {
    return OutdoorPoint(
      latitude: (json['lat'] as num).toDouble(),
      longitude: (json['lon'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch((json['t'] as num).toInt()),
      altitude: (json['alt'] as num?)?.toDouble(),
      horizontalAccuracy: (json['acc'] as num?)?.toDouble(),
      speed: (json['spd'] as num?)?.toDouble(),
    );
  }

  GpsSample toSample() => GpsSample(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    altitude: altitude,
    horizontalAccuracy: horizontalAccuracy,
    speed: speed,
  );
}

class OutdoorSession {
  OutdoorSession({
    required this.id,
    required this.activityType,
    required this.startedAt,
    this.finishedAt,
    this.pausedSeconds = 0,
    this.points = const [],
    this.relativeAltitudeDeltas = const [],
    this.status = 'finished',
    this.notes,
  });

  final String id;
  final String activityType;
  final DateTime startedAt;
  DateTime? finishedAt;
  double pausedSeconds;
  List<OutdoorPoint> points;
  List<double> relativeAltitudeDeltas;
  String status;
  String? notes;

  SessionSummaryStats get summary => summarizeSession(
    samples: points.map((p) => p.toSample()).toList(),
    startedAt: startedAt,
    finishedAt: finishedAt ?? DateTime.now(),
    pausedDuration: Duration(milliseconds: (pausedSeconds * 1000).round()),
    relativeAltitudeDeltas: relativeAltitudeDeltas.isEmpty
        ? null
        : relativeAltitudeDeltas,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'activityType': activityType,
    'startedAtEpochMs': startedAt.millisecondsSinceEpoch,
    'finishedAtEpochMs': finishedAt?.millisecondsSinceEpoch,
    'pausedSeconds': pausedSeconds,
    'points': points.map((p) => p.toJson()).toList(),
    'relativeAltitudeDeltas': relativeAltitudeDeltas,
    'status': status,
    'notes': notes,
  };

  factory OutdoorSession.fromJson(Map<String, dynamic> json) {
    return OutdoorSession(
      id: json['id'] as String,
      activityType: json['activityType'] as String? ?? 'walk',
      startedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['startedAtEpochMs'] as num).toInt(),
      ),
      finishedAt: json['finishedAtEpochMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (json['finishedAtEpochMs'] as num).toInt(),
            ),
      pausedSeconds: (json['pausedSeconds'] as num?)?.toDouble() ?? 0,
      points: ((json['points'] as List?) ?? [])
          .map((e) => OutdoorPoint.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      relativeAltitudeDeltas: ((json['relativeAltitudeDeltas'] as List?) ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      status: json['status'] as String? ?? 'finished',
      notes: json['notes'] as String?,
    );
  }
}

class ActivityBridge {
  ActivityBridge._();

  static const _channel = MethodChannel('aster/activity');
  static const _events = EventChannel('aster/activity_events');

  static Stream<Map<String, dynamic>>? _eventStream;

  static Stream<Map<String, dynamic>> get events {
    _eventStream ??= _events.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    });
    return _eventStream!;
  }

  static Future<Map<String, dynamic>> platformInfo() async {
    if (kIsWeb) return {'healthKitAvailable': false};
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('platformInfo');
    return Map<String, dynamic>.from(raw ?? {});
  }

  static Future<Map<String, dynamic>> requestHealthAuthorization() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'requestHealthAuthorization',
    );
    return Map<String, dynamic>.from(raw ?? {});
  }

  static Future<Map<String, dynamic>> requestMotionAuthorization() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'requestMotionAuthorization',
    );
    return Map<String, dynamic>.from(raw ?? {});
  }

  static Future<Map<String, dynamic>> requestLocationAuthorization({
    bool always = true,
  }) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'requestLocationAuthorization',
      {'always': always},
    );
    return Map<String, dynamic>.from(raw ?? {});
  }

  static Future<DailyActivitySnapshot> getDailyActivity({DateTime? day}) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getDailyActivity',
      day == null ? null : {'dayEpochMs': day.millisecondsSinceEpoch},
    );
    return DailyActivitySnapshot.fromMap(raw ?? {});
  }

  static Future<List<HistoryDay>> getHistory({int days = 30}) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getHistory',
      {'days': days},
    );
    final list = (raw?['days'] as List?) ?? [];
    return list.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return HistoryDay(
        dayStart: DateTime.fromMillisecondsSinceEpoch(
          (map['dayStartEpochMs'] as num).toInt(),
        ),
        steps: (map['steps'] as num?)?.round() ?? 0,
      );
    }).toList();
  }

  static Future<void> startOutdoorSession() async {
    await _channel.invokeMethod<void>('startOutdoorSession');
  }

  static Future<void> pauseOutdoorSession() async {
    await _channel.invokeMethod<void>('pauseOutdoorSession');
  }

  static Future<void> resumeOutdoorSession() async {
    await _channel.invokeMethod<void>('resumeOutdoorSession');
  }

  static Future<Map<String, dynamic>> stopOutdoorSession() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'stopOutdoorSession',
    );
    return Map<String, dynamic>.from(raw ?? {});
  }

  static Future<void> saveSession(OutdoorSession session) async {
    await _channel.invokeMethod<void>('saveSession', jsonEncode(session.toJson()));
  }

  static Future<List<OutdoorSession>> loadSessions() async {
    final raw = await _channel.invokeMethod<String>('loadSessions');
    final list = jsonDecode(raw ?? '[]') as List;
    return list
        .map((e) => OutdoorSession.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  static Future<OutdoorSession?> loadSession(String id) async {
    final raw = await _channel.invokeMethod<String?>('loadSession', {'id': id});
    if (raw == null) return null;
    return OutdoorSession.fromJson(
      (jsonDecode(raw) as Map).cast<String, dynamic>(),
    );
  }

  static Future<void> deleteSession(String id) async {
    await _channel.invokeMethod<void>('deleteSession', {'id': id});
  }
}
