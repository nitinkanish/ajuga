import '../motion/activity_bridge.dart';
import 'aggregate.dart';
import 'insights.dart';
import 'models.dart';
import 'time.dart';
import 'weekly.dart';

enum TimelineKind { movement, workout, outdoor, calendar, note, motion, gap, focus }

class TimelineEntry {
  const TimelineEntry({
    required this.start,
    required this.title,
    required this.detail,
    required this.kind,
    this.end,
    this.editableId,
    this.uncertain = false,
  });

  final DateTime start;
  final DateTime? end;
  final String title;
  final String detail;
  final TimelineKind kind;
  final String? editableId;
  final bool uncertain;
}

class LifeSignals {
  const LifeSignals({
    this.sleepMinutes,
    this.activeEnergyKcal,
    this.workouts = const [],
    this.motionSegments = const [],
    this.healthStatus = 'unavailable',
    this.motionStatus = 'unavailable',
  });

  final int? sleepMinutes;
  final double? activeEnergyKcal;
  final List<SignalEvent> workouts;
  final List<SignalEvent> motionSegments;
  final String healthStatus;
  final String motionStatus;

  factory LifeSignals.fromMap(Map<String, dynamic> map) {
    return LifeSignals(
      sleepMinutes: (map['sleepMinutes'] as num?)?.round(),
      activeEnergyKcal: (map['activeEnergyKcal'] as num?)?.toDouble(),
      workouts: _events(map['workouts']),
      motionSegments: _events(map['motionSegments']),
      healthStatus: map['healthStatus'] as String? ?? 'unavailable',
      motionStatus: map['motionStatus'] as String? ?? 'unavailable',
    );
  }
}

class SignalEvent {
  const SignalEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.detail = '',
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final String detail;
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
}

List<SignalEvent> _events(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((item) {
    final map = (item as Map).cast<String, dynamic>();
    return SignalEvent(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Recorded',
      start: DateTime.fromMillisecondsSinceEpoch((map['startEpochMs'] as num).toInt()),
      end: DateTime.fromMillisecondsSinceEpoch((map['endEpochMs'] as num).toInt()),
      detail: map['detail'] as String? ?? '',
    );
  }).toList();
}

class LifeDashboardModel {
  const LifeDashboardModel({
    required this.greeting,
    required this.dateLabel,
    required this.overview,
    required this.baseline,
    required this.steps,
    required this.distance,
    required this.sleepMinutes,
    required this.energyKcal,
    required this.timeline,
    required this.insight,
    required this.suggestion,
    required this.sources,
    required this.latestCheckIn,
  });

  final String greeting;
  final String dateLabel;
  final String overview;
  final String baseline;
  final Reading steps;
  final Reading distance;
  final int? sleepMinutes;
  final double? energyKcal;
  final List<TimelineEntry> timeline;
  final Insight insight;
  final ExperimentSuggestion? suggestion;
  final List<SourceStatus> sources;
  final CheckIn? latestCheckIn;
}

class SourceStatus {
  const SourceStatus({required this.label, required this.detail});

  final String label;
  final String detail;
}

LifeDashboardModel buildLifeDashboard({
  required DateTime now,
  required Reading steps,
  required Reading distance,
  required List<DayMovement> history,
  required LifeSignals signals,
  required List<CalendarEvent> calendar,
  required bool calendarEnabled,
  required List<CheckIn> checkIns,
  required List<LifeNote> notes,
  required List<FocusRecord> focusSessions,
  required List<OutdoorSession> outdoor,
  required List<DaySignal> patternDays,
  required int minimumObservations,
  required Set<String> dismissedExperiments,
  String? cachedOverview,
  String? cachedFingerprint,
}) {
  final todaySteps = steps.known ? steps.value!.round() : null;
  final fingerprint = summaryFingerprint(
    dayKey: formatDay(now.year, now.month, now.day),
    steps: todaySteps,
    distanceMeters: distance.value,
    sleepMinutes: signals.sleepMinutes,
    checkInCount: checkIns.length,
    noteCount: notes.length,
    workoutCount: signals.workouts.length,
  );
  final overview = cachedFingerprint == fingerprint && cachedOverview != null && cachedOverview.isNotEmpty
      ? cachedOverview
      : dailyOverview(
          steps: steps,
          distanceMeters: distance,
          sleepMinutes: signals.sleepMinutes,
        );
  final insight = detectPatterns(patternDays, minimumObservations: minimumObservations);
  final review = buildWeeklyReview(
    now: now,
    days: patternDays
        .map(
          (day) => WeekInput(
            day: day.day,
            steps: day.steps,
            sleepHours: day.sleepHours,
            energy: day.energy,
            focus: day.afternoonFocus,
          ),
        )
        .toList(),
    insights: [insight],
    dismissedIds: dismissedExperiments,
  );
  final todayCheckIns = checkIns.where((item) => sameLocalDay(item.at, now)).toList()
    ..sort((a, b) => b.at.compareTo(a.at));
  return LifeDashboardModel(
    greeting: greetingForHour(now.hour),
    dateLabel: _dateLabel(now),
    overview: overview,
    baseline: movementBaseline(todaySteps: todaySteps, prior: history),
    steps: steps,
    distance: distance,
    sleepMinutes: signals.sleepMinutes,
    energyKcal: signals.activeEnergyKcal,
    timeline: buildTimeline(
      now: now,
      signals: signals,
      calendar: calendarEnabled ? calendar : const [],
      notes: notes,
      outdoor: outdoor,
      focusSessions: focusSessions,
    ),
    insight: insight,
    suggestion: review.suggestion,
    sources: [
      SourceStatus(
        label: 'Movement',
        detail: steps.known ? steps.source : 'Not available',
      ),
      SourceStatus(
        label: 'Sleep',
        detail: signals.sleepMinutes == null ? 'Not recorded' : 'Apple Health',
      ),
      SourceStatus(
        label: 'Calendar',
        detail: calendarEnabled ? 'On for today’s events' : 'Off',
      ),
      SourceStatus(
        label: 'Outdoor routes',
        detail: 'Only while you track a walk, run, or hike',
      ),
    ],
    latestCheckIn: todayCheckIns.isEmpty ? null : todayCheckIns.first,
  );
}

List<TimelineEntry> buildTimeline({
  required DateTime now,
  required LifeSignals signals,
  required List<CalendarEvent> calendar,
  required List<LifeNote> notes,
  required List<OutdoorSession> outdoor,
  required List<FocusRecord> focusSessions,
}) {
  final entries = <TimelineEntry>[
    for (final workout in signals.workouts)
      TimelineEntry(
        start: workout.start,
        end: workout.end,
        title: workout.title,
        detail: 'Workout recorded in Apple Health. The daily step total already includes this movement.',
        kind: TimelineKind.workout,
      ),
    for (final segment in signals.motionSegments)
      TimelineEntry(
        start: segment.start,
        end: segment.end,
        title: 'Motion classified as ${segment.title}',
        detail: segment.detail.isEmpty
            ? 'This is a motion classification, not a record of what you were doing.'
            : segment.detail,
        kind: TimelineKind.motion,
        uncertain: true,
      ),
    for (final event in calendar)
      TimelineEntry(
        start: event.start,
        end: event.end,
        title: event.title,
        detail: 'On your calendar. This does not show whether you attended.',
        kind: TimelineKind.calendar,
      ),
    for (final session in outdoor)
      if (sameLocalDay(session.startedAt, now))
        TimelineEntry(
          start: session.startedAt,
          end: session.finishedAt,
          title: 'Outdoor ${session.activityType}',
          detail: 'A route you started in Ajuga. Location was used only for this session.',
          kind: TimelineKind.outdoor,
        ),
    for (final note in notes)
      if (sameLocalDay(note.at, now))
        TimelineEntry(
          start: note.at,
          title: 'Note',
          detail: note.text,
          kind: TimelineKind.note,
          editableId: note.id,
        ),
    for (final session in focusSessions)
      if (sameLocalDay(session.startedAt, now))
        TimelineEntry(
          start: session.startedAt,
          end: session.endedAt,
          title: 'Focus timer',
          detail:
              '${session.elapsedSeconds ~/ 60} min on a ${session.plannedSeconds ~/ 60} min timer. Timer time is not a measure of productive work.',
          kind: TimelineKind.focus,
        ),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final withGaps = <TimelineEntry>[];
  for (var i = 0; i < entries.length; i++) {
    withGaps.add(entries[i]);
    if (i == entries.length - 1) continue;
    final gap = entries[i + 1].start.difference(entries[i].end ?? entries[i].start);
    if (gap.inHours >= 3) {
      withGaps.add(
        TimelineEntry(
          start: entries[i].end ?? entries[i].start,
          end: entries[i + 1].start,
          title: 'Gap in recorded signals',
          detail: 'Nothing was recorded in this stretch. That is not proof of inactivity.',
          kind: TimelineKind.gap,
          uncertain: true,
        ),
      );
    }
  }
  return withGaps;
}

List<DaySignal> patternDaysFrom({
  required List<HistoryDay> history,
  required List<CheckIn> checkIns,
  required LifeSignals todaySignals,
  required DateTime today,
  required List<OutdoorSession> outdoor,
}) {
  final byDay = <String, DaySignal>{};
  for (final day in history) {
    final key = formatDay(day.dayStart.year, day.dayStart.month, day.dayStart.day);
    byDay[key] = DaySignal(day: startOfLocalDay(day.dayStart), steps: day.steps);
  }
  final grouped = <String, List<CheckIn>>{};
  for (final checkIn in checkIns) {
    final key = formatDay(checkIn.at.year, checkIn.at.month, checkIn.at.day);
    grouped.putIfAbsent(key, () => []).add(checkIn);
  }
  for (final entry in grouped.entries) {
    final sample = entry.value.first;
    final day = startOfLocalDay(sample.at);
    final afternoon = entry.value.where((item) => item.at.hour >= 12).map((item) => item.focus.toDouble());
    final energy = entry.value.map((item) => item.energy.toDouble());
    final existing = byDay[entry.key];
    byDay[entry.key] = DaySignal(
      day: day,
      steps: existing?.steps,
      sleepHours: sameLocalDay(day, today) && todaySignals.sleepMinutes != null
          ? todaySignals.sleepMinutes! / 60
          : existing?.sleepHours,
      middayWalkRecorded: _middayWalk(day, outdoor, todaySignals),
      afternoonFocus: afternoon.isEmpty ? null : afternoon.reduce((a, b) => a + b) / afternoon.length,
      energy: energy.isEmpty ? null : energy.reduce((a, b) => a + b) / energy.length,
    );
  }
  return byDay.values.toList();
}

bool? _middayWalk(DateTime day, List<OutdoorSession> outdoor, LifeSignals signals) {
  bool overlaps(DateTime start) {
    if (!sameLocalDay(start, day)) return false;
    return start.hour >= 11 && start.hour < 14;
  }

  for (final session in outdoor) {
    if (overlaps(session.startedAt)) return true;
  }
  for (final workout in signals.workouts) {
    if (overlaps(workout.start) && sameLocalDay(day, workout.start)) return true;
  }
  for (final segment in signals.motionSegments) {
    final title = segment.title.toLowerCase();
    if ((title.contains('walk') || title.contains('run')) && overlaps(segment.start)) {
      return true;
    }
  }
  return null;
}

String _dateLabel(DateTime day) {
  const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${weekdays[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';
}
