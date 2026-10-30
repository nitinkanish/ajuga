import 'insights.dart';
import 'time.dart';

class WeekSlice {
  const WeekSlice({
    required this.start,
    required this.end,
    required this.measuredStepDays,
    this.totalSteps,
    this.averageSleepHours,
    this.averageEnergy,
    this.averageFocus,
    this.completedFocusSessions = 0,
  });

  final DateTime start;
  final DateTime end;
  final int measuredStepDays;
  final int? totalSteps;
  final double? averageSleepHours;
  final double? averageEnergy;
  final double? averageFocus;
  final int completedFocusSessions;
}

class ExperimentSuggestion {
  const ExperimentSuggestion({
    required this.id,
    required this.title,
    required this.hypothesis,
    required this.durationDays,
    required this.measurement,
    required this.stopHint,
  });

  final String id;
  final String title;
  final String hypothesis;
  final int durationDays;
  final String measurement;
  final String stopHint;
}

class WeeklyReview {
  const WeeklyReview({
    required this.current,
    required this.previous,
    required this.comparison,
    required this.observations,
    required this.suggestion,
  });

  final WeekSlice current;
  final WeekSlice? previous;
  final String comparison;
  final List<Insight> observations;
  final ExperimentSuggestion? suggestion;
}

class WeekInput {
  const WeekInput({
    required this.day,
    this.steps,
    this.sleepHours,
    this.energy,
    this.focus,
    this.focusSessions = 0,
  });

  final DateTime day;
  final int? steps;
  final double? sleepHours;
  final double? energy;
  final double? focus;
  final int focusSessions;
}

WeeklyReview buildWeeklyReview({
  required DateTime now,
  required List<WeekInput> days,
  required List<Insight> insights,
  required Set<String> dismissedIds,
}) {
  final thisStart = weekStartMonday(now);
  final prevStart = thisStart.subtract(const Duration(days: 7));
  final current = _slice(days, thisStart);
  final previous = _slice(days, prevStart);
  final previousUseful = previous.measuredStepDays > 0 ||
      previous.averageEnergy != null ||
      previous.completedFocusSessions > 0;
  final comparison = _compare(current, previousUseful ? previous : null);
  final observations = insights.where((item) => item.actionable).take(2).toList();
  final suggestion = _suggestion(
    weekStart: thisStart,
    insight: observations.isEmpty ? null : observations.first,
    dismissedIds: dismissedIds,
  );
  return WeeklyReview(
    current: current,
    previous: previousUseful ? previous : null,
    comparison: comparison,
    observations: observations,
    suggestion: suggestion,
  );
}

WeekSlice _slice(List<WeekInput> days, DateTime start) {
  final end = start.add(const Duration(days: 6));
  final inWeek = days.where((day) {
    final local = startOfLocalDay(day.day);
    return !local.isBefore(start) && !local.isAfter(end);
  }).toList();
  final steps = inWeek.map((day) => day.steps).whereType<int>().toList();
  final sleep = inWeek.map((day) => day.sleepHours).whereType<double>().toList();
  final energy = inWeek.map((day) => day.energy).whereType<double>().toList();
  final focus = inWeek.map((day) => day.focus).whereType<double>().toList();
  return WeekSlice(
    start: start,
    end: end,
    measuredStepDays: steps.length,
    totalSteps: steps.isEmpty ? null : steps.reduce((a, b) => a + b),
    averageSleepHours: sleep.isEmpty ? null : sleep.reduce((a, b) => a + b) / sleep.length,
    averageEnergy: energy.isEmpty ? null : energy.reduce((a, b) => a + b) / energy.length,
    averageFocus: focus.isEmpty ? null : focus.reduce((a, b) => a + b) / focus.length,
    completedFocusSessions: inWeek.fold(0, (sum, day) => sum + day.focusSessions),
  );
}

String _compare(WeekSlice current, WeekSlice? previous) {
  if (previous == null) {
    return 'There is not enough earlier history to compare with this week.';
  }
  if (current.totalSteps != null &&
      previous.totalSteps != null &&
      current.measuredStepDays >= 3 &&
      previous.measuredStepDays >= 3 &&
      previous.totalSteps! > 0) {
    final delta = (current.totalSteps! - previous.totalSteps!) / previous.totalSteps!;
    final percent = (delta * 100).round().abs();
    if (delta >= 0.1) {
      return 'Recorded steps are about $percent% higher than the previous week. A quieter week is not a failure.';
    }
    if (delta <= -0.1) {
      return 'Recorded steps are about $percent% lower than the previous week. A quieter week is not a failure.';
    }
    return 'Recorded steps are close to the previous week.';
  }
  if (current.averageEnergy != null && previous.averageEnergy != null) {
    final delta = current.averageEnergy! - previous.averageEnergy!;
    if (delta >= 0.4) return 'Average energy ratings are higher than the previous week.';
    if (delta <= -0.4) return 'Average energy ratings are lower than the previous week.';
    return 'Average energy ratings are close to the previous week.';
  }
  return 'There are not enough measured days in both weeks to compare them.';
}

ExperimentSuggestion? _suggestion({
  required DateTime weekStart,
  required Insight? insight,
  required Set<String> dismissedIds,
}) {
  final candidates = <ExperimentSuggestion>[
    if (insight != null && insight.statement.contains('midday walk'))
      ExperimentSuggestion(
        id: '${formatDay(weekStart.year, weekStart.month, weekStart.day)}:midday-walk',
        title: 'Try a short walk before your usual afternoon',
        hypothesis: 'A recorded midday walk might line up with higher afternoon focus ratings.',
        durationDays: 7,
        measurement: 'Log afternoon focus on the days you walk and the days you do not.',
        stopHint: 'Stop or dismiss this whenever you want. It is an experiment, not a prescription.',
      ),
    if (insight != null && insight.statement.contains('recorded sleep'))
      ExperimentSuggestion(
        id: '${formatDay(weekStart.year, weekStart.month, weekStart.day)}:sleep-note',
        title: 'Compare energy after different nights',
        hypothesis: 'Nights with more recorded sleep might line up with higher next-day energy ratings.',
        durationDays: 7,
        measurement: 'Keep the sleep record and one morning energy check-in.',
        stopHint: 'Stop or dismiss this whenever you want. It is an experiment, not a prescription.',
      ),
    ExperimentSuggestion(
      id: '${formatDay(weekStart.year, weekStart.month, weekStart.day)}:check-in',
      title: 'Log energy on three different days',
      hypothesis: 'A few check-ins are enough to see whether your ratings vary across the week.',
      durationDays: 7,
      measurement: 'Three energy check-ins, on any days you choose.',
      stopHint: 'Skip check-ins entirely if you do not want them. Dismiss this card to hide it.',
    ),
  ];
  for (final candidate in candidates) {
    if (!dismissedIds.contains(candidate.id)) return candidate;
  }
  return null;
}
