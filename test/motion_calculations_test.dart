import 'package:aster/motion/calculations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('distance', () {
    test('haversine is near zero for identical points', () {
      expect(
        distanceMetersBetween(lat1: 12.97, lon1: 77.59, lat2: 12.97, lon2: 77.59),
        closeTo(0, 0.01),
      );
    });

    test('roughly 111 meters per 0.001 degree latitude', () {
      final d = distanceMetersBetween(lat1: 0, lon1: 0, lat2: 0.001, lon2: 0);
      expect(d, closeTo(111.2, 1.5));
    });
  });

  group('gps filtering', () {
    final t0 = DateTime.utc(2026, 1, 1, 8);
    test('rejects poor accuracy', () {
      final result = evaluateGpsSample(
        sample: GpsSample(
          latitude: 1,
          longitude: 1,
          timestamp: t0,
          horizontalAccuracy: 80,
        ),
      );
      expect(result.accepted, isFalse);
      expect(result.rejectReason, 'poor accuracy');
    });

    test('rejects stationary drift', () {
      final previous = GpsSample(
        latitude: 12.97,
        longitude: 77.59,
        timestamp: t0,
        horizontalAccuracy: 10,
      );
      final next = GpsSample(
        latitude: 12.970001,
        longitude: 77.59,
        timestamp: t0.add(const Duration(seconds: 5)),
        horizontalAccuracy: 10,
      );
      final result = evaluateGpsSample(sample: next, previous: previous);
      expect(result.accepted, isFalse);
      expect(result.rejectReason, 'stationary drift');
    });

    test('rejects impossible jumps', () {
      final previous = GpsSample(
        latitude: 12.97,
        longitude: 77.59,
        timestamp: t0,
        horizontalAccuracy: 8,
      );
      final next = GpsSample(
        latitude: 13.0,
        longitude: 77.59,
        timestamp: t0.add(const Duration(seconds: 2)),
        horizontalAccuracy: 8,
      );
      final result = evaluateGpsSample(sample: next, previous: previous);
      expect(result.accepted, isFalse);
      expect(result.rejectReason, 'impossible jump');
    });

    test('accepts a normal walking step', () {
      final previous = GpsSample(
        latitude: 12.97,
        longitude: 77.59,
        timestamp: t0,
        horizontalAccuracy: 8,
      );
      final next = GpsSample(
        latitude: 12.97005,
        longitude: 77.59,
        timestamp: t0.add(const Duration(seconds: 8)),
        horizontalAccuracy: 8,
      );
      final result = evaluateGpsSample(sample: next, previous: previous);
      expect(result.accepted, isTrue);
    });
  });

  group('pace and speed', () {
    test('average speed from distance and time', () {
      expect(averageSpeedMps(distanceMeters: 1000, movingSeconds: 400), closeTo(2.5, 0.001));
    });

    test('pace formatting', () {
      expect(paceSecondsPerKm(2.5), closeTo(400, 0.1));
      expect(formatPace(400), '6:40 /km');
      expect(formatPace(null), '—');
    });
  });

  group('elevation', () {
    test('smooths noise and counts meaningful ascent', () {
      final series = <double?>[100, 100.3, 99.8, 101, 103, 105, 104.5, 108, 110];
      final stats = elevationFromSamples(series, window: 3, minStepMeters: 1.0);
      expect(stats.gainMeters, greaterThan(5));
      expect(stats.lossMeters, lessThan(3));
      expect(stats.source, 'gps');
    });
  });

  group('session state', () {
    test('start pause resume finish discard', () {
      var state = OutdoorSessionState.idle;
      state = transitionSession(current: state, action: 'start');
      expect(state, OutdoorSessionState.tracking);
      state = transitionSession(current: state, action: 'pause');
      expect(state, OutdoorSessionState.paused);
      state = transitionSession(current: state, action: 'resume');
      expect(state, OutdoorSessionState.tracking);
      state = transitionSession(current: state, action: 'finish');
      expect(state, OutdoorSessionState.finished);
      state = transitionSession(current: state, action: 'discard');
      expect(state, OutdoorSessionState.idle);
    });

    test('invalid transitions are ignored', () {
      expect(
        transitionSession(current: OutdoorSessionState.idle, action: 'pause'),
        OutdoorSessionState.idle,
      );
    });
  });

  group('reconciliation', () {
    test('HealthKit wins when present', () {
      final r = reconcileDailyActivity(
        healthKitSteps: 8000,
        healthKitDistanceMeters: 5600,
        pedometerSteps: 8100,
        pedometerDistanceMeters: 5700,
      );
      expect(r.steps, 8000);
      expect(r.source, 'HealthKit');
    });

    test('falls back to Core Motion', () {
      final r = reconcileDailyActivity(pedometerSteps: 1200, pedometerDistanceMeters: 900);
      expect(r.steps, 1200);
      expect(r.source, 'Core Motion');
    });

    test('unavailable when both missing', () {
      final r = reconcileDailyActivity();
      expect(r.source, 'unavailable');
      expect(r.steps, isNull);
    });
  });

  group('summarizeSession', () {
    test('builds distance and elevation from a short walk', () {
      final t0 = DateTime.utc(2026, 3, 1, 7);
      final samples = <GpsSample>[
        GpsSample(latitude: 12.97, longitude: 77.59, timestamp: t0, horizontalAccuracy: 6, altitude: 900),
        GpsSample(
          latitude: 12.9702,
          longitude: 77.59,
          timestamp: t0.add(const Duration(seconds: 40)),
          horizontalAccuracy: 6,
          altitude: 903,
        ),
        GpsSample(
          latitude: 12.9704,
          longitude: 77.59,
          timestamp: t0.add(const Duration(seconds: 80)),
          horizontalAccuracy: 6,
          altitude: 907,
        ),
      ];
      final summary = summarizeSession(
        samples: samples,
        startedAt: t0,
        finishedAt: t0.add(const Duration(seconds: 90)),
        pausedDuration: Duration.zero,
      );
      expect(summary.distanceMeters, greaterThan(30));
      expect(summary.avgSpeedMps, greaterThan(0));
      expect(summary.elevation.gainMeters, greaterThanOrEqualTo(0));
    });
  });
}
