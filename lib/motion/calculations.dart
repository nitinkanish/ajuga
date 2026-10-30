import 'dart:math' as math;

/// Pure GPS / activity math used by outdoor tracking.
/// Kept free of Flutter and platform channels so it can be unit tested.

class GpsSample {
  const GpsSample({
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
}

class FilteredPoint {
  const FilteredPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.altitude,
    this.horizontalAccuracy,
    this.speed,
    this.accepted = true,
    this.rejectReason,
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? altitude;
  final double? horizontalAccuracy;
  final double? speed;
  final bool accepted;
  final String? rejectReason;
}

class ElevationStats {
  const ElevationStats({
    required this.gainMeters,
    required this.lossMeters,
    required this.minAltitude,
    required this.maxAltitude,
    required this.source,
  });

  final double gainMeters;
  final double lossMeters;
  final double? minAltitude;
  final double? maxAltitude;
  final String source;
}

class SessionSummaryStats {
  const SessionSummaryStats({
    required this.distanceMeters,
    required this.elapsedSeconds,
    required this.movingSeconds,
    required this.avgSpeedMps,
    required this.avgPaceSecPerKm,
    required this.elevation,
  });

  final double distanceMeters;
  final double elapsedSeconds;
  final double movingSeconds;
  final double avgSpeedMps;
  final double? avgPaceSecPerKm;
  final ElevationStats elevation;
}

const earthRadiusMeters = 6371000.0;

/// Haversine distance between two WGS84 points.
double distanceMetersBetween({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _rad(double degrees) => degrees * math.pi / 180.0;

/// Reject inaccurate / impossible GPS jumps before they affect distance.
FilteredPoint evaluateGpsSample({
  required GpsSample sample,
  GpsSample? previous,
  double maxHorizontalAccuracy = 35,
  double maxSpeedMps = 12, // ~43 km/h — walking/running/hiking ceiling
  double minMoveMeters = 1.5,
}) {
  final accuracy = sample.horizontalAccuracy;
  if (accuracy != null && accuracy < 0) {
    return _reject(sample, 'negative accuracy');
  }
  if (accuracy != null && accuracy > maxHorizontalAccuracy) {
    return _reject(sample, 'poor accuracy');
  }
  if (previous == null) {
    return FilteredPoint(
      latitude: sample.latitude,
      longitude: sample.longitude,
      timestamp: sample.timestamp,
      altitude: sample.altitude,
      horizontalAccuracy: sample.horizontalAccuracy,
      speed: sample.speed,
    );
  }
  if (!sample.timestamp.isAfter(previous.timestamp)) {
    return _reject(sample, 'non-increasing timestamp');
  }
  final dt = sample.timestamp.difference(previous.timestamp).inMilliseconds / 1000.0;
  if (dt <= 0) {
    return _reject(sample, 'zero interval');
  }
  final distance = distanceMetersBetween(
    lat1: previous.latitude,
    lon1: previous.longitude,
    lat2: sample.latitude,
    lon2: sample.longitude,
  );
  if (distance < minMoveMeters) {
    return _reject(sample, 'stationary drift');
  }
  final impliedSpeed = distance / dt;
  if (impliedSpeed > maxSpeedMps) {
    return _reject(sample, 'impossible jump');
  }
  return FilteredPoint(
    latitude: sample.latitude,
    longitude: sample.longitude,
    timestamp: sample.timestamp,
    altitude: sample.altitude,
    horizontalAccuracy: sample.horizontalAccuracy,
    speed: sample.speed ?? impliedSpeed,
  );
}

FilteredPoint _reject(GpsSample sample, String reason) {
  return FilteredPoint(
    latitude: sample.latitude,
    longitude: sample.longitude,
    timestamp: sample.timestamp,
    altitude: sample.altitude,
    horizontalAccuracy: sample.horizontalAccuracy,
    speed: sample.speed,
    accepted: false,
    rejectReason: reason,
  );
}

List<FilteredPoint> filterRoute(
  List<GpsSample> samples, {
  double maxHorizontalAccuracy = 35,
  double maxSpeedMps = 12,
  double minMoveMeters = 1.5,
}) {
  final out = <FilteredPoint>[];
  GpsSample? lastAccepted;
  for (final sample in samples) {
    final filtered = evaluateGpsSample(
      sample: sample,
      previous: lastAccepted,
      maxHorizontalAccuracy: maxHorizontalAccuracy,
      maxSpeedMps: maxSpeedMps,
      minMoveMeters: minMoveMeters,
    );
    out.add(filtered);
    if (filtered.accepted) {
      lastAccepted = sample;
    }
  }
  return out;
}

double routeDistanceMeters(List<FilteredPoint> points) {
  final accepted = points.where((p) => p.accepted).toList();
  if (accepted.length < 2) return 0;
  var total = 0.0;
  for (var i = 1; i < accepted.length; i++) {
    total += distanceMetersBetween(
      lat1: accepted[i - 1].latitude,
      lon1: accepted[i - 1].longitude,
      lat2: accepted[i].latitude,
      lon2: accepted[i].longitude,
    );
  }
  return total;
}

/// Smooth altitude series with a simple moving average, then accumulate ascent/descent.
ElevationStats elevationFromSamples(
  List<double?> altitudes, {
  int window = 5,
  double minStepMeters = 1.2,
  String source = 'gps',
}) {
  final values = altitudes.whereType<double>().toList();
  if (values.isEmpty) {
    return const ElevationStats(
      gainMeters: 0,
      lossMeters: 0,
      minAltitude: null,
      maxAltitude: null,
      source: 'none',
    );
  }
  final smoothed = _movingAverage(values, window.clamp(1, values.length));
  var gain = 0.0;
  var loss = 0.0;
  for (var i = 1; i < smoothed.length; i++) {
    final delta = smoothed[i] - smoothed[i - 1];
    if (delta >= minStepMeters) {
      gain += delta;
    } else if (delta <= -minStepMeters) {
      loss += -delta;
    }
  }
  return ElevationStats(
    gainMeters: gain,
    lossMeters: loss,
    minAltitude: smoothed.reduce(math.min),
    maxAltitude: smoothed.reduce(math.max),
    source: source,
  );
}

List<double> _movingAverage(List<double> values, int window) {
  if (window <= 1) return List<double>.from(values);
  final out = <double>[];
  for (var i = 0; i < values.length; i++) {
    final start = math.max(0, i - window + 1);
    final slice = values.sublist(start, i + 1);
    out.add(slice.reduce((a, b) => a + b) / slice.length);
  }
  return out;
}

/// Average speed in m/s from distance and moving duration.
double averageSpeedMps({required double distanceMeters, required double movingSeconds}) {
  if (movingSeconds <= 0 || distanceMeters <= 0) return 0;
  return distanceMeters / movingSeconds;
}

/// Pace as seconds per kilometer. Null when speed is effectively zero.
double? paceSecondsPerKm(double speedMps) {
  if (speedMps <= 0.05) return null;
  return 1000.0 / speedMps;
}

String formatPace(double? secondsPerKm) {
  if (secondsPerKm == null || !secondsPerKm.isFinite) return '—';
  final total = secondsPerKm.round().clamp(0, 99 * 60);
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')} /km';
}

String formatDuration(Duration value) {
  final h = value.inHours;
  final m = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '$h:$m:$s';
  return '$m:$s';
}

String formatDistanceKm(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(meters >= 10000 ? 1 : 2)} km';
}

SessionSummaryStats summarizeSession({
  required List<GpsSample> samples,
  required DateTime startedAt,
  required DateTime finishedAt,
  required Duration pausedDuration,
  List<double>? relativeAltitudeDeltas,
}) {
  final filtered = filterRoute(samples);
  final distance = routeDistanceMeters(filtered);
  final elapsed = finishedAt.difference(startedAt) - pausedDuration;
  final elapsedSeconds = elapsed.inMilliseconds / 1000.0;
  final accepted = filtered.where((p) => p.accepted).toList();
  var movingSeconds = 0.0;
  for (var i = 1; i < accepted.length; i++) {
    movingSeconds +=
        accepted[i].timestamp.difference(accepted[i - 1].timestamp).inMilliseconds / 1000.0;
  }
  if (movingSeconds <= 0) movingSeconds = math.max(0, elapsedSeconds);

  ElevationStats elevation;
  if (relativeAltitudeDeltas != null && relativeAltitudeDeltas.isNotEmpty) {
    var cumulative = 0.0;
    final series = <double>[0];
    for (final delta in relativeAltitudeDeltas) {
      cumulative += delta;
      series.add(cumulative);
    }
    elevation = elevationFromSamples(series, source: 'barometer');
  } else {
    elevation = elevationFromSamples(
      accepted.map((p) => p.altitude).toList(),
      source: 'gps',
    );
  }

  final avg = averageSpeedMps(distanceMeters: distance, movingSeconds: movingSeconds);
  return SessionSummaryStats(
    distanceMeters: distance,
    elapsedSeconds: math.max(0, elapsedSeconds),
    movingSeconds: movingSeconds,
    avgSpeedMps: avg,
    avgPaceSecPerKm: paceSecondsPerKm(avg),
    elevation: elevation,
  );
}

enum OutdoorSessionState { idle, tracking, paused, finished }

OutdoorSessionState transitionSession({
  required OutdoorSessionState current,
  required String action,
}) {
  switch (action) {
    case 'start':
      if (current == OutdoorSessionState.idle || current == OutdoorSessionState.finished) {
        return OutdoorSessionState.tracking;
      }
      return current;
    case 'pause':
      if (current == OutdoorSessionState.tracking) return OutdoorSessionState.paused;
      return current;
    case 'resume':
      if (current == OutdoorSessionState.paused) return OutdoorSessionState.tracking;
      return current;
    case 'finish':
      if (current == OutdoorSessionState.tracking || current == OutdoorSessionState.paused) {
        return OutdoorSessionState.finished;
      }
      return current;
    case 'discard':
      return OutdoorSessionState.idle;
    default:
      return current;
  }
}

/// Prefer HealthKit daily totals as source of truth; fall back to Core Motion
/// only when HealthKit values are unavailable (null). Never sum both.
class ActivityReconciliation {
  const ActivityReconciliation({
    required this.steps,
    required this.distanceMeters,
    required this.source,
  });

  final int? steps;
  final double? distanceMeters;
  final String source;
}

ActivityReconciliation reconcileDailyActivity({
  int? healthKitSteps,
  double? healthKitDistanceMeters,
  int? pedometerSteps,
  double? pedometerDistanceMeters,
}) {
  if (healthKitSteps != null || healthKitDistanceMeters != null) {
    return ActivityReconciliation(
      steps: healthKitSteps,
      distanceMeters: healthKitDistanceMeters,
      source: 'HealthKit',
    );
  }
  if (pedometerSteps != null || pedometerDistanceMeters != null) {
    return ActivityReconciliation(
      steps: pedometerSteps,
      distanceMeters: pedometerDistanceMeters,
      source: 'Core Motion',
    );
  }
  return const ActivityReconciliation(steps: null, distanceMeters: null, source: 'unavailable');
}
