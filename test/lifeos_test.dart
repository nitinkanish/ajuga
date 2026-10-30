import 'package:aster/lifeos/aggregate.dart';
import 'package:aster/lifeos/dashboard.dart';
import 'package:aster/lifeos/focus.dart';
import 'package:aster/lifeos/insights.dart';
import 'package:aster/lifeos/models.dart';
import 'package:aster/lifeos/reminders.dart';
import 'package:aster/lifeos/store.dart';
import 'package:aster/lifeos/time.dart';
import 'package:aster/lifeos/weekly.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('time zones and day boundaries', () {
    test('India offset keeps a fixed 24 hour day', () {
      final clock = ZonedClock(indiaOffset);
      final length = clock.lengthOfLocalDay(2026, 10, 29);
      expect(length, const Duration(hours: 24));
      final before = DateTime.utc(2026, 10, 29, 18, 29);
      final after = DateTime.utc(2026, 10, 29, 18, 31);
      expect(clock.dayKey(before), '2026-10-29');
      expect(clock.dayKey(after), '2026-10-30');
    });

    test('US spring-forward day is 23 hours and fall-back day is 25 hours', () {
      final clock = ZonedClock(usEastern2026);
      expect(clock.lengthOfLocalDay(2026, 3, 8), const Duration(hours: 23));
      expect(clock.lengthOfLocalDay(2026, 11, 1), const Duration(hours: 25));
      expect(clock.dayKey(DateTime.utc(2026, 3, 8, 6, 30)), '2026-03-08');
      expect(clock.dayKey(DateTime.utc(2026, 3, 8, 7, 30)), '2026-03-08');
    });

    test('local midnight splits late and early samples', () {
      final late = DateTime(2026, 10, 29, 23, 59);
      final early = DateTime(2026, 10, 30, 0, 1);
      expect(sameLocalDay(late, early), isFalse);
      expect(weekStartMonday(DateTime(2026, 10, 29)), DateTime(2026, 10, 26));
    });
  });

  group('aggregation', () {
    test('HealthKit steps win and are not added to Core Motion', () {
      final reading = reconcileSteps(healthKitSteps: 1000, pedometerSteps: 4000);
      expect(reading.value, 1000);
      expect(reading.source, 'Apple Health');
      expect(reading.kind, ValueKind.measured);
    });

    test('missing health data stays unavailable instead of zero', () {
      final reading = reconcileSteps();
      expect(reading.known, isFalse);
      expect(reading.value, isNull);
      expect(
        movementBaseline(todaySteps: null, prior: const []),
        contains('not evidence of an inactive day'),
      );
    });

    test('overlapping and out-of-order sleep samples merge once', () {
      final start = DateTime(2026, 10, 29, 23);
      final minutes = mergedAsleepMinutes([
        TimeSpan(start: start.add(const Duration(hours: 2)), end: start.add(const Duration(hours: 5))),
        TimeSpan(start: start, end: start.add(const Duration(hours: 3))),
        TimeSpan(start: start.add(const Duration(hours: 2)), end: start.add(const Duration(hours: 3))),
      ]);
      expect(minutes, 5 * 60);
      expect(mergedAsleepMinutes(const []), isNull);
    });

    test('baseline ignores days without a measurement', () {
      final text = movementBaseline(
        todaySteps: 8000,
        prior: [
          DayMovement(day: DateTime(2026, 10, 26), steps: null),
          DayMovement(day: DateTime(2026, 10, 27), steps: 4000),
          DayMovement(day: DateTime(2026, 10, 28), steps: 4000),
          DayMovement(day: DateTime(2026, 10, 25), steps: 4000),
        ],
      );
      expect(text, contains('above'));
      expect(text, contains('4000'));
    });
  });

  group('insights', () {
    test('stays quiet below the sample threshold', () {
      final insight = detectPatterns([
        DaySignal(day: DateTime(2026, 10, 1), steps: 100, afternoonFocus: 4, middayWalkRecorded: true),
        DaySignal(day: DateTime(2026, 10, 2), steps: 100, afternoonFocus: 2),
      ], minimumObservations: 5);
      expect(insight.evidence, Evidence.insufficient);
      expect(insight.statement, contains('not logged enough'));
      expect(insight.sampleCount, lessThan(5));
    });

    test('reports a midday-walk correlation without claiming cause', () {
      final days = [
        for (var day = 1; day <= 3; day++)
          DaySignal(
            day: DateTime(2026, 10, day),
            steps: 5000,
            middayWalkRecorded: true,
            afternoonFocus: 4.6,
          ),
        for (var day = 4; day <= 6; day++)
          DaySignal(
            day: DateTime(2026, 10, day),
            steps: 5000,
            afternoonFocus: 2.2,
          ),
      ];
      final insight = detectPatterns(days, minimumObservations: 5);
      expect(insight.evidence, Evidence.moderate);
      expect(insight.sampleCount, 6);
      expect(insight.statement, contains('midday walk'));
      expect(insight.statement.toLowerCase(), isNot(contains('caused')));
      expect(insight.caveat.toLowerCase(), contains('not evidence'));
      expect(insight.periodStart, DateTime(2026, 10, 1));
    });

    test('sleep comparison treats missing sleep as unknown', () {
      final days = [
        for (var day = 1; day <= 3; day++)
          DaySignal(day: DateTime(2026, 10, day), sleepHours: 5, energy: 2),
        for (var day = 4; day <= 6; day++)
          DaySignal(day: DateTime(2026, 10, day), sleepHours: 8, energy: 4.5),
        DaySignal(day: DateTime(2026, 10, 7), energy: 1),
      ];
      final insight = detectPatterns(days, minimumObservations: 5);
      expect(insight.statement, contains('recorded sleep'));
      expect(insight.sampleCount, 6);
    });
  });

  group('weekly review', () {
    test('compares two measured weeks and does not call a quieter week a failure', () {
      final days = [
        for (var day = 26; day <= 29; day++) WeekInput(day: DateTime(2026, 10, day), steps: 10000),
        for (var day = 19; day <= 25; day++) WeekInput(day: DateTime(2026, 10, day), steps: 5000),
      ];
      final review = buildWeeklyReview(
        now: DateTime(2026, 10, 29),
        days: days,
        insights: const [],
        dismissedIds: {},
      );
      expect(review.current.totalSteps, 40000);
      expect(review.previous?.totalSteps, 35000);
      expect(review.comparison, contains('higher'));
      expect(review.comparison.toLowerCase(), contains('not a failure'));
    });

    test('suggestion includes a hypothesis, duration, measurement, and can be dismissed', () {
      final review = buildWeeklyReview(
        now: DateTime(2026, 10, 29),
        days: const [],
        insights: const [],
        dismissedIds: {},
      );
      final suggestion = review.suggestion!;
      expect(suggestion.hypothesis, isNotEmpty);
      expect(suggestion.durationDays, 7);
      expect(suggestion.measurement, isNotEmpty);
      expect(suggestion.stopHint, contains('Dismiss'));
      final hidden = buildWeeklyReview(
        now: DateTime(2026, 10, 29),
        days: const [],
        insights: const [],
        dismissedIds: {suggestion.id},
      );
      expect(hidden.suggestion, isNull);
    });
  });

  group('focus timer', () {
    final start = DateTime(2026, 10, 29, 9);
    test('start, pause, resume, and finish keep elapsed time', () {
      var snapshot = const FocusSnapshot(plannedSeconds: 60);
      snapshot = transitionFocus(snapshot, 'start', start);
      expect(snapshot.phase, FocusPhase.running);
      snapshot = transitionFocus(snapshot, 'pause', start.add(const Duration(seconds: 20)));
      expect(snapshot.phase, FocusPhase.paused);
      expect(snapshot.elapsedSeconds, 20);
      snapshot = transitionFocus(snapshot, 'resume', start.add(const Duration(seconds: 30)));
      snapshot = transitionFocus(snapshot, 'finish', start.add(const Duration(seconds: 45)));
      expect(snapshot.phase, FocusPhase.finished);
      expect(snapshot.elapsedSeconds, 35);
    });

    test('recovers a finished session from wall clock after termination', () {
      final running = FocusSnapshot(
        phase: FocusPhase.running,
        plannedSeconds: 60,
        elapsedSeconds: 10,
        runningSince: start,
        startedAt: start,
      );
      final restored = reconcileFocus(running, start.add(const Duration(minutes: 5)));
      expect(restored.phase, FocusPhase.finished);
      expect(restored.elapsedSeconds, 60);
      final decoded = FocusSnapshot.fromJson(running.toJson());
      expect(decoded.phase, FocusPhase.running);
    });

    test('pause and idle do not schedule a completion alert', () {
      expect(
        focusCompletionPlan(running: false, now: start, remainingSeconds: 30),
        isNull,
      );
      final plan = focusCompletionPlan(running: true, now: start, remainingSeconds: 30);
      expect(plan!.id, focusReminderId);
      expect(plan.fireAt, start.add(const Duration(seconds: 30)));
    });
  });

  group('reminders', () {
    test('weekly fire moves to the next matching weekday', () {
      final next = nextWeeklyFire(
        now: DateTime(2026, 10, 26, 10),
        weekday: DateTime.monday,
        hour: 9,
        minute: 0,
      );
      expect(next, DateTime(2026, 11, 2, 9));
      final laterToday = nextWeeklyFire(
        now: DateTime(2026, 10, 26, 8),
        weekday: DateTime.monday,
        hour: 9,
        minute: 0,
      );
      expect(laterToday, DateTime(2026, 10, 26, 9));
    });

    test('disabled reminders cancel instead of scheduling', () {
      expect(
        weeklyReviewPlan(
          now: DateTime(2026, 10, 29),
          enabled: false,
          weekday: DateTime.sunday,
          hour: 18,
          minute: 0,
        ),
        isNull,
      );
    });
  });

  group('timeline and cache', () {
    test('calendar stays off unless enabled and gaps are labeled as gaps', () {
      final now = DateTime(2026, 10, 29, 18);
      final timeline = buildTimeline(
        now: now,
        signals: LifeSignals(
          workouts: [
            SignalEvent(
              id: 'w',
              title: 'Walk',
              start: DateTime(2026, 10, 29, 8),
              end: DateTime(2026, 10, 29, 9),
            ),
          ],
        ),
        calendar: [
          CalendarEvent(
            id: 'c',
            title: 'Standup',
            start: DateTime(2026, 10, 29, 15),
            end: DateTime(2026, 10, 29, 15, 30),
          ),
        ],
        notes: const [],
        outdoor: const [],
        focusSessions: const [],
      );
      expect(timeline.any((entry) => entry.kind == TimelineKind.calendar), isTrue);
      final hidden = buildLifeDashboard(
        now: now,
        steps: const Reading.unavailable('unavailable'),
        distance: const Reading.unavailable('unavailable'),
        history: const [],
        signals: const LifeSignals(),
        calendar: [
          CalendarEvent(
            id: 'c',
            title: 'Standup',
            start: DateTime(2026, 10, 29, 15),
            end: DateTime(2026, 10, 29, 15, 30),
          ),
        ],
        calendarEnabled: false,
        checkIns: const [],
        notes: const [],
        focusSessions: const [],
        outdoor: const [],
        patternDays: const [],
        minimumObservations: 5,
        dismissedExperiments: const {},
      );
      expect(hidden.timeline.any((entry) => entry.kind == TimelineKind.calendar), isFalse);
      expect(timeline.any((entry) => entry.kind == TimelineKind.gap), isTrue);
      expect(timeline.firstWhere((entry) => entry.kind == TimelineKind.gap).detail, contains('not proof'));
    });

    test('fingerprint changes when source data changes', () {
      final first = summaryFingerprint(
        dayKey: '2026-10-29',
        steps: 10,
        distanceMeters: 1,
        sleepMinutes: null,
        checkInCount: 0,
        noteCount: 0,
        workoutCount: 0,
      );
      final second = summaryFingerprint(
        dayKey: '2026-10-29',
        steps: 11,
        distanceMeters: 1,
        sleepMinutes: null,
        checkInCount: 0,
        noteCount: 0,
        workoutCount: 0,
      );
      expect(first, isNot(second));
    });
  });

  group('deletion', () {
    test('deleting LifeOS data removes check-ins and the derived cache', () async {
      SharedPreferences.setMockInitialValues({});
      final store = LifeStore();
      await store.save(
        LifeDocument(
          cache: const SummaryCache(dayKey: '2026-10-29', fingerprint: 'a', overview: 'cached'),
          checkIns: [
            CheckIn(
              id: '1',
              at: DateTime(2026, 10, 29, 8),
              energy: 3,
              mood: 3,
              focus: 3,
              stress: 2,
            ),
          ],
        ),
      );
      final updated = await store.update((current) {
        return current.copyWith(checkIns: current.checkIns.where((item) => item.id != '1').toList());
      });
      expect(updated.checkIns, isEmpty);
      expect(updated.cache, isNull);
      await store.save(
        const LifeDocument(
          cache: SummaryCache(dayKey: '2026-10-29', fingerprint: 'b', overview: 'again'),
        ),
      );
      await store.deleteAll();
      final cleared = await store.load();
      expect(cleared.isEmpty, isTrue);
      expect(cleared.cache, isNull);
    });

    test('corrupt stored json does not crash or invent records', () {
      final document = LifeDocument.decode('{not json');
      expect(document.checkIns, isEmpty);
      expect(document.cache, isNull);
    });
  });
}
