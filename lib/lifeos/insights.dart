import 'time.dart';

enum Evidence { insufficient, weak, moderate }

class Insight {
  const Insight({
    required this.statement,
    required this.caveat,
    required this.sampleCount,
    required this.periodStart,
    required this.periodEnd,
    required this.evidence,
  });

  final String statement;
  final String caveat;
  final int sampleCount;
  final DateTime periodStart;
  final DateTime periodEnd;
  final Evidence evidence;

  bool get actionable => evidence != Evidence.insufficient;
}

class DaySignal {
  const DaySignal({
    required this.day,
    this.steps,
    this.sleepHours,
    this.middayWalkRecorded,
    this.afternoonFocus,
    this.energy,
  });

  final DateTime day;
  final int? steps;

  /// Null when sleep was not recorded. Never treat null as zero hours.
  final double? sleepHours;

  /// True only when a walk, workout, or outdoor session was recorded at midday.
  /// False is not used; absence stays null.
  final bool? middayWalkRecorded;
  final double? afternoonFocus;
  final double? energy;
}

const correlationCaveat =
    'This is a correlation in your own logs, not evidence that one thing caused the other. It is not a diagnosis or a reason to change medication.';

Insight detectPatterns(
  List<DaySignal> days, {
  int minimumObservations = 5,
}) {
  final sorted = [...days]..sort((a, b) => a.day.compareTo(b.day));
  if (sorted.isEmpty) {
    final today = DateTime.now();
    return Insight(
      statement: 'You have not logged enough data to identify a reliable pattern yet.',
      caveat: correlationCaveat,
      sampleCount: 0,
      periodStart: today,
      periodEnd: today,
      evidence: Evidence.insufficient,
    );
  }
  final start = startOfLocalDay(sorted.first.day);
  final end = startOfLocalDay(sorted.last.day);

  final walkInsight = _walkFocusInsight(sorted, start, end, minimumObservations);
  if (walkInsight.actionable) return walkInsight;

  final sleepInsight = _sleepEnergyInsight(sorted, start, end, minimumObservations);
  if (sleepInsight.actionable) return sleepInsight;

  final rated = sorted.where((day) => day.energy != null || day.afternoonFocus != null).length;
  if (rated < minimumObservations) {
    return Insight(
      statement: 'You have not logged enough data to identify a reliable pattern yet.',
      caveat: correlationCaveat,
      sampleCount: rated,
      periodStart: start,
      periodEnd: end,
      evidence: Evidence.insufficient,
    );
  }
  return Insight(
    statement: 'Your recent check-ins do not show a consistent pattern yet.',
    caveat: correlationCaveat,
    sampleCount: rated,
    periodStart: start,
    periodEnd: end,
    evidence: Evidence.insufficient,
  );
}

Insight _walkFocusInsight(
  List<DaySignal> days,
  DateTime start,
  DateTime end,
  int minimum,
) {
  final paired = days.where((day) {
    return day.afternoonFocus != null && (day.middayWalkRecorded != null || day.steps != null);
  }).toList();
  final withWalk = paired.where((day) => day.middayWalkRecorded == true).toList();
  final withoutRecord = paired.where((day) => day.middayWalkRecorded != true).toList();
  if (paired.length < minimum || withWalk.length < 3 || withoutRecord.length < 3) {
    return Insight(
      statement: 'You have not logged enough data to identify a reliable pattern yet.',
      caveat: correlationCaveat,
      sampleCount: paired.length,
      periodStart: start,
      periodEnd: end,
      evidence: Evidence.insufficient,
    );
  }
  final walkMean = _mean(withWalk.map((day) => day.afternoonFocus!));
  final otherMean = _mean(withoutRecord.map((day) => day.afternoonFocus!));
  final diff = walkMean - otherMean;
  if (diff < 0.4) {
    return Insight(
      statement: 'Afternoon focus ratings are not consistently different on days with a recorded midday walk.',
      caveat: correlationCaveat,
      sampleCount: paired.length,
      periodStart: start,
      periodEnd: end,
      evidence: Evidence.insufficient,
    );
  }
  final evidence = diff >= 0.8 ? Evidence.moderate : Evidence.weak;
  final tone = evidence == Evidence.weak ? 'The difference is small.' : 'The difference shows up across this sample.';
  return Insight(
    statement:
        'On days with a recorded midday walk, afternoon focus ratings were often higher (${walkMean.toStringAsFixed(1)} vs ${otherMean.toStringAsFixed(1)}). $tone A missing walk record is not proof you stayed still.',
    caveat: correlationCaveat,
    sampleCount: paired.length,
    periodStart: start,
    periodEnd: end,
    evidence: evidence,
  );
}

Insight _sleepEnergyInsight(
  List<DaySignal> days,
  DateTime start,
  DateTime end,
  int minimum,
) {
  final paired = days.where((day) => day.sleepHours != null && day.energy != null).toList();
  if (paired.length < minimum) {
    return Insight(
      statement: 'You have not logged enough data to identify a reliable pattern yet.',
      caveat: correlationCaveat,
      sampleCount: paired.length,
      periodStart: start,
      periodEnd: end,
      evidence: Evidence.insufficient,
    );
  }
  final sleeps = paired.map((day) => day.sleepHours!).toList()..sort();
  final median = sleeps.length.isOdd
      ? sleeps[sleeps.length ~/ 2]
      : (sleeps[sleeps.length ~/ 2 - 1] + sleeps[sleeps.length ~/ 2]) / 2;
  final low = paired.where((day) => day.sleepHours! < median).toList();
  final high = paired.where((day) => day.sleepHours! >= median).toList();
  if (low.length < 3 || high.length < 3) {
    return Insight(
      statement: 'Sleep and energy logs are too uneven to compare yet.',
      caveat: correlationCaveat,
      sampleCount: paired.length,
      periodStart: start,
      periodEnd: end,
      evidence: Evidence.insufficient,
    );
  }
  final lowMean = _mean(low.map((day) => day.energy!));
  final highMean = _mean(high.map((day) => day.energy!));
  final diff = highMean - lowMean;
  if (diff < 0.4) {
    return Insight(
      statement: 'Energy ratings are not consistently different after nights with less recorded sleep.',
      caveat: correlationCaveat,
      sampleCount: paired.length,
      periodStart: start,
      periodEnd: end,
      evidence: Evidence.insufficient,
    );
  }
  final evidence = diff >= 0.8 ? Evidence.moderate : Evidence.weak;
  return Insight(
    statement:
        'Energy ratings have tended to be lower after nights with less recorded sleep (${lowMean.toStringAsFixed(1)} vs ${highMean.toStringAsFixed(1)}). Recorded sleep can be incomplete.',
    caveat: correlationCaveat,
    sampleCount: paired.length,
    periodStart: start,
    periodEnd: end,
    evidence: evidence,
  );
}

double _mean(Iterable<double> values) {
  final list = values.toList();
  if (list.isEmpty) return 0;
  return list.reduce((a, b) => a + b) / list.length;
}
