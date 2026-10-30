import 'package:flutter/material.dart';

import '../../lifeos/insights.dart';
import '../../lifeos/load.dart';
import '../../lifeos/store.dart';
import '../../lifeos/weekly.dart';
import '../../motion/activity_bridge.dart';
import 'life_chrome.dart';

class WeeklyScreen extends StatefulWidget {
  const WeeklyScreen({super.key});

  @override
  State<WeeklyScreen> createState() => _WeeklyScreenState();
}

class _WeeklyScreenState extends State<WeeklyScreen> {
  final _store = LifeStore();
  WeeklyReview? _review;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final document = await _store.load();
    final model = await LifeLoader.loadDashboard(document);
    final history = await _history();
    final days = <WeekInput>[
      for (final day in history)
        WeekInput(
          day: day.dayStart,
          steps: day.steps,
          energy: _average(document.checkIns.where((item) => _same(item.at, day.dayStart)).map((item) => item.energy)),
          focus: _average(document.checkIns.where((item) => _same(item.at, day.dayStart) && item.at.hour >= 12).map((item) => item.focus)),
          focusSessions: document.focusSessions.where((item) => _same(item.startedAt, day.dayStart)).length,
        ),
    ];
    final review = buildWeeklyReview(
      now: DateTime.now(),
      days: days,
      insights: [model.insight],
      dismissedIds: document.dismissedExperiments.toSet(),
    );
    if (!mounted) return;
    setState(() {
      _review = review;
      _loading = false;
    });
  }

  Future<void> _dismiss(String id) async {
    await _store.update((current) {
      return current.copyWith(dismissedExperiments: [...current.dismissedExperiments, id]);
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    final review = _review;
    return LifePage(
      title: 'This week',
      subtitle: 'Compared with your own recent weeks',
      child: _loading || review == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Text(review.comparison, style: TextStyle(color: colors.ink, height: 1.4, fontSize: 16)),
                const SizedBox(height: 14),
                _line(colors, 'Steps', _steps(review.current.totalSteps), '${review.current.measuredStepDays} measured days'),
                _line(colors, 'Energy', _avg(review.current.averageEnergy), 'From check-ins you chose to log'),
                _line(colors, 'Focus timers', '${review.current.completedFocusSessions}', 'Timer time is not productive work'),
                _line(
                  colors,
                  'Sleep',
                  review.current.averageSleepHours == null ? 'Not recorded' : '${review.current.averageSleepHours!.toStringAsFixed(1)} h',
                  'Only when Apple Health has samples',
                ),
                const SizedBox(height: 16),
                Text('Observations', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 8),
                if (review.observations.isEmpty)
                  Text(
                    'Not enough evidence for an observation this week.',
                    style: TextStyle(color: colors.muted, height: 1.4),
                  )
                else
                  for (final insight in review.observations) _observation(colors, insight),
                const SizedBox(height: 8),
                if (review.suggestion == null)
                  Text('No suggestion is showing. You can dismiss these at any time.', style: TextStyle(color: colors.muted))
                else
                  LifeCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review.suggestion!.title, style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text('Hypothesis: ${review.suggestion!.hypothesis}', style: TextStyle(color: colors.ink, height: 1.35)),
                        const SizedBox(height: 6),
                        Text('${review.suggestion!.durationDays} days. Measure: ${review.suggestion!.measurement}', style: TextStyle(color: colors.muted, height: 1.35)),
                        const SizedBox(height: 6),
                        Text(review.suggestion!.stopHint, style: TextStyle(color: colors.muted, height: 1.35)),
                        const SizedBox(height: 8),
                        LifeButton(label: 'Dismiss experiment', filled: false, onTap: () => _dismiss(review.suggestion!.id)),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _line(LifeColors colors, String label, String value, String caption) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LifeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: colors.muted, fontSize: 12)),
            Text(value, style: TextStyle(color: colors.ink, fontSize: 20, fontWeight: FontWeight.w700)),
            Text(caption, style: TextStyle(color: colors.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _observation(LifeColors colors, Insight insight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LifeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(insight.statement, style: TextStyle(color: colors.ink, height: 1.4)),
            const SizedBox(height: 6),
            Text(
              '${insight.sampleCount} observations · ${insight.evidence.name}',
              style: TextStyle(color: colors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _steps(int? steps) => steps == null ? 'Not recorded' : '$steps';
  String _avg(double? value) => value == null ? 'Not recorded' : value.toStringAsFixed(1);

  double? _average(Iterable<int> values) {
    final list = values.toList();
    if (list.isEmpty) return null;
    return list.reduce((a, b) => a + b) / list.length;
  }

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<List<HistoryDay>> _history() async {
    try {
      return await ActivityBridge.getHistory(days: 21);
    } catch (_) {
      return const [];
    }
  }
}
