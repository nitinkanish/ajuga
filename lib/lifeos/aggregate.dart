import 'models.dart';

/// Prefer a HealthKit daily total when a sample exists. Use Core Motion only
/// when HealthKit has no sample. Never add the two together.
Reading reconcileSteps({int? healthKitSteps, int? pedometerSteps}) {
  if (healthKitSteps != null) {
    return Reading.measured(healthKitSteps.toDouble(), source: 'Apple Health');
  }
  if (pedometerSteps != null) {
    return Reading.measured(pedometerSteps.toDouble(), source: 'Motion & Fitness');
  }
  return const Reading.unavailable('unavailable');
}

Reading reconcileDistance({double? healthKitMeters, double? pedometerMeters}) {
  if (healthKitMeters != null) {
    return Reading.measured(healthKitMeters, source: 'Apple Health');
  }
  if (pedometerMeters != null) {
    return Reading.measured(pedometerMeters, source: 'Motion & Fitness');
  }
  return const Reading.unavailable('unavailable');
}

/// Merge overlapping asleep intervals. An empty list is "no sample", not zero sleep.
int? mergedAsleepMinutes(List<TimeSpan> spans) {
  final usable = spans.where((span) => span.valid).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  if (usable.isEmpty) return null;
  var cursorStart = usable.first.start;
  var cursorEnd = usable.first.end;
  var total = Duration.zero;
  for (final span in usable.skip(1)) {
    if (!span.start.isAfter(cursorEnd)) {
      if (span.end.isAfter(cursorEnd)) cursorEnd = span.end;
    } else {
      total += cursorEnd.difference(cursorStart);
      cursorStart = span.start;
      cursorEnd = span.end;
    }
  }
  total += cursorEnd.difference(cursorStart);
  final minutes = total.inMinutes;
  return minutes < 0 ? null : minutes;
}

class DayMovement {
  const DayMovement({required this.day, this.steps});

  final DateTime day;
  final int? steps;
}

/// Compare today with the user's own recent measured days.
/// Null steps are skipped and are never treated as zero.
String movementBaseline({
  required int? todaySteps,
  required List<DayMovement> prior,
}) {
  if (todaySteps == null) {
    return 'Today’s step total is not available. That is not evidence of an inactive day.';
  }
  final measured = prior.map((day) => day.steps).whereType<int>().toList();
  if (measured.length < 3) {
    return 'Not enough of your own recent days to compare yet.';
  }
  final average = measured.reduce((a, b) => a + b) / measured.length;
  if (average <= 0) {
    return 'Your recent measured days average near zero steps.';
  }
  final delta = (todaySteps - average) / average;
  final rounded = average.round();
  if (delta >= 0.1) {
    return 'Steps are above your recent average of $rounded.';
  }
  if (delta <= -0.1) {
    return 'Steps are below your recent average of $rounded.';
  }
  return 'Steps are close to your recent average of $rounded.';
}

String dailyOverview({
  required Reading steps,
  required Reading distanceMeters,
  required int? sleepMinutes,
}) {
  final parts = <String>[];
  if (steps.known) {
    parts.add('${steps.value!.round()} steps from ${steps.source}');
  }
  if (distanceMeters.known) {
    final km = distanceMeters.value! / 1000;
    parts.add('${km.toStringAsFixed(1)} km walking or running distance');
  }
  if (sleepMinutes != null) {
    final hours = sleepMinutes / 60;
    parts.add('${hours.toStringAsFixed(1)} h of recorded sleep');
  }
  if (parts.isEmpty) {
    return 'No measured movement or sleep is available for today. Missing access is not the same as an empty day.';
  }
  return 'Today includes ${parts.join(', ')}.';
}

String summaryFingerprint({
  required String dayKey,
  int? steps,
  double? distanceMeters,
  int? sleepMinutes,
  required int checkInCount,
  required int noteCount,
  required int workoutCount,
}) {
  return '$dayKey|${steps ?? 'x'}|${distanceMeters ?? 'x'}|${sleepMinutes ?? 'x'}|$checkInCount|$noteCount|$workoutCount';
}
