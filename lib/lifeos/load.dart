import '../motion/activity_bridge.dart';
import 'aggregate.dart';
import 'dashboard.dart';
import 'models.dart';
import 'native.dart';
import 'time.dart';

class LifeLoader {
  static Future<LifeDashboardModel> loadDashboard(LifeDocument document) async {
    final now = DateTime.now();
    final snapshot = await _snapshot();
    final history = await _history();
    final signalsMap = await LifeNative.lifeSignals();
    final signals = LifeSignals.fromMap(signalsMap);
    final outdoor = await _outdoor();
    final calendar = document.settings.calendarEnabled ? await _calendar() : const <CalendarEvent>[];
    final prior = history
        .where((day) => !sameLocalDay(day.dayStart, now))
        .map((day) => DayMovement(day: day.dayStart, steps: day.steps))
        .toList();
    return buildLifeDashboard(
      now: now,
      steps: _stepsReading(snapshot),
      distance: _distanceReading(snapshot),
      history: prior,
      signals: signals,
      calendar: calendar,
      calendarEnabled: document.settings.calendarEnabled,
      checkIns: document.checkIns,
      notes: document.notes,
      focusSessions: document.focusSessions,
      outdoor: outdoor,
      patternDays: patternDaysFrom(
        history: history,
        checkIns: document.checkIns,
        todaySignals: signals,
        today: now,
        outdoor: outdoor,
      ),
      minimumObservations: document.settings.minimumObservations,
      dismissedExperiments: document.dismissedExperiments.toSet(),
      cachedOverview: document.cache?.overview,
      cachedFingerprint: document.cache?.fingerprint,
    );
  }

  static Reading _stepsReading(DailyActivitySnapshot? snapshot) {
    if (snapshot == null || snapshot.source == 'unavailable') {
      return const Reading.unavailable('unavailable');
    }
    if (snapshot.steps == null) return Reading.unavailable(snapshot.source);
    final source = snapshot.source == 'HealthKit' ? 'Apple Health' : 'Motion & Fitness';
    return Reading.measured(snapshot.steps!.toDouble(), source: source);
  }

  static Reading _distanceReading(DailyActivitySnapshot? snapshot) {
    if (snapshot == null || snapshot.distanceMeters == null || snapshot.source == 'unavailable') {
      return const Reading.unavailable('unavailable');
    }
    final source = snapshot.source == 'HealthKit' ? 'Apple Health' : 'Motion & Fitness';
    return Reading.measured(snapshot.distanceMeters!, source: source);
  }

  static Future<DailyActivitySnapshot?> _snapshot() async {
    try {
      return await ActivityBridge.getDailyActivity();
    } catch (_) {
      return null;
    }
  }

  static Future<List<HistoryDay>> _history() async {
    try {
      return await ActivityBridge.getHistory(days: 14);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<OutdoorSession>> _outdoor() async {
    try {
      return await ActivityBridge.loadSessions();
    } catch (_) {
      return const [];
    }
  }

  static Future<List<CalendarEvent>> _calendar() async {
    final rows = await LifeNative.todayEvents();
    return rows.map((row) {
      return CalendarEvent(
        id: row['id'] as String? ?? '',
        title: row['title'] as String? ?? 'Busy',
        start: DateTime.fromMillisecondsSinceEpoch((row['startEpochMs'] as num).toInt()),
        end: DateTime.fromMillisecondsSinceEpoch((row['endEpochMs'] as num).toInt()),
      );
    }).toList();
  }
}
