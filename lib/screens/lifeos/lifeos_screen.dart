import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../lifeos/aggregate.dart';
import '../../lifeos/dashboard.dart';
import '../../lifeos/insights.dart';
import '../../lifeos/load.dart';
import '../../lifeos/models.dart';
import '../../lifeos/store.dart';
import '../../lifeos/time.dart';
import '../../theme.dart';
import '../../widgets/pressable.dart';
import 'checkins_screen.dart';
import 'focus_screen.dart';
import 'life_chrome.dart';
import 'privacy_screen.dart';
import 'timeline_screen.dart';
import 'weekly_screen.dart';

class LifeOsScreen extends StatefulWidget {
  const LifeOsScreen({super.key});

  @override
  State<LifeOsScreen> createState() => _LifeOsScreenState();
}

class _LifeOsScreenState extends State<LifeOsScreen> {
  final _store = LifeStore();
  LifeDashboardModel? _model;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final document = await _store.load();
      final model = await LifeLoader.loadDashboard(document);
      final now = DateTime.now();
      final fingerprint = summaryFingerprint(
        dayKey: formatDay(now.year, now.month, now.day),
        steps: model.steps.known ? model.steps.value!.round() : null,
        distanceMeters: model.distance.value,
        sleepMinutes: model.sleepMinutes,
        checkInCount: document.checkIns.length,
        noteCount: document.notes.length,
        workoutCount: model.timeline.where((item) => item.kind == TimelineKind.workout).length,
      );
      if (document.cache?.fingerprint != fingerprint) {
        await _store.save(
          document.copyWith(
            cache: SummaryCache(
              dayKey: formatDay(now.year, now.month, now.day),
              fingerprint: fingerprint,
              overview: model.overview,
            ),
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _model = model;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'LifeOS could not refresh just now.';
      });
    }
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
    final model = _model;
    return LifePage(
      title: 'LifeOS',
      subtitle: model?.dateLabel ?? 'Today',
      child: _loading && model == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  Text(
                    model?.greeting ?? 'Good day',
                    style: TextStyle(color: colors.ink, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    model?.overview ?? 'No summary yet.',
                    style: TextStyle(color: colors.ink, height: 1.4, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    model?.baseline ?? '',
                    style: TextStyle(color: colors.muted, height: 1.4, fontSize: 13),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: const TextStyle(color: AppColors.danger)),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _Metric(
                        label: 'Steps',
                        value: _reading(model?.steps),
                        caption: model?.steps.source ?? 'Not recorded',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _Metric(
                        label: 'Distance',
                        value: model?.distance.known == true
                            ? '${(model!.distance.value! / 1000).toStringAsFixed(1)} km'
                            : '—',
                        caption: model?.distance.known == true ? model!.distance.source : 'Not recorded',
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _Metric(
                        label: 'Sleep',
                        value: model?.sleepMinutes == null
                            ? '—'
                            : '${(model!.sleepMinutes! / 60).toStringAsFixed(1)} h',
                        caption: model?.sleepMinutes == null ? 'Not recorded' : 'Apple Health',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _Metric(
                        label: 'Energy',
                        value: model?.latestCheckIn == null ? '—' : '${model!.latestCheckIn!.energy}/5',
                        caption: model?.energyKcal == null
                            ? 'Check-in, not a health score'
                            : '${model!.energyKcal!.round()} kcal active',
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LifeCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Today’s timeline', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        if (model == null || model.timeline.isEmpty)
                          Text(
                            'No signals recorded yet. An empty timeline is not an empty day.',
                            style: TextStyle(color: colors.muted, height: 1.4),
                          )
                        else
                          for (final item in model.timeline.take(4))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                '${_clock(item.start)}  ${item.title}',
                                style: TextStyle(color: colors.ink),
                              ),
                            ),
                        const SizedBox(height: 8),
                        Pressable(
                          onTap: () async {
                            await Navigator.of(context).push(
                              CupertinoPageRoute<void>(builder: (_) => const TimelineScreen()),
                            );
                            _load();
                          },
                          child: const Text('Open timeline', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (model != null) _InsightCard(insight: model.insight),
                  const SizedBox(height: 12),
                  if (model?.suggestion != null)
                    LifeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('One thing to try', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(model!.suggestion!.title, style: TextStyle(color: colors.ink, fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text(model.suggestion!.hypothesis, style: TextStyle(color: colors.muted, height: 1.35)),
                          const SizedBox(height: 8),
                          Text(
                            '${model.suggestion!.durationDays} days · ${model.suggestion!.measurement}',
                            style: TextStyle(color: colors.ink, height: 1.35),
                          ),
                          const SizedBox(height: 10),
                          Pressable(
                            onTap: () => _dismiss(model.suggestion!.id),
                            child: Text('Dismiss', style: TextStyle(color: colors.muted, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  LifeButton(
                    label: 'Log energy and focus',
                    onTap: () async {
                      await Navigator.of(context).push(
                        CupertinoPageRoute<void>(builder: (_) => const CheckInsScreen()),
                      );
                      _load();
                    },
                  ),
                  const SizedBox(height: 10),
                  LifeButton(
                    label: 'Weekly review',
                    filled: false,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(builder: (_) => const WeeklyScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  LifeButton(
                    label: 'Focus timer',
                    filled: false,
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute<void>(builder: (_) => const FocusScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Pressable(
                    onTap: () async {
                      await Navigator.of(context).push(
                        CupertinoPageRoute<void>(builder: (_) => const PrivacyScreen()),
                      );
                      _load();
                    },
                    child: LifeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Data on this iPhone', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          for (final source in model?.sources ?? const <SourceStatus>[])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text('${source.label}: ${source.detail}', style: TextStyle(color: colors.muted)),
                            ),
                          const SizedBox(height: 6),
                          const Text('Privacy and permissions', style: TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _reading(Reading? reading) {
    if (reading == null || !reading.known) return '—';
    final value = reading.value!.round();
    final text = value.toString();
    final grouped = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) grouped.write(',');
      grouped.write(text[i]);
    }
    return grouped.toString();
  }

  String _clock(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.caption});

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    return LifeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: colors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: colors.ink, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(caption, style: TextStyle(color: colors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    final period = '${insight.periodStart.month}/${insight.periodStart.day}–${insight.periodEnd.month}/${insight.periodEnd.day}';
    return LifeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal pattern', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(insight.statement, style: TextStyle(color: colors.ink, height: 1.4)),
          const SizedBox(height: 8),
          Text(
            '$period · ${insight.sampleCount} observations · ${insight.evidence.name}',
            style: TextStyle(color: colors.muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(insight.caveat, style: TextStyle(color: colors.muted, fontSize: 12, height: 1.35)),
        ],
      ),
    );
  }
}
