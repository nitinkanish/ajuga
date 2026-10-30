import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../motion/activity_bridge.dart';
import '../../motion/activity_targets.dart';
import '../../motion/calculations.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/pressable.dart';
import 'metric_detail_screen.dart';
import 'outdoor_hub_screen.dart';

class DailyActivityScreen extends StatefulWidget {
  const DailyActivityScreen({super.key});

  @override
  State<DailyActivityScreen> createState() => _DailyActivityScreenState();
}

class _DailyActivityScreenState extends State<DailyActivityScreen>
    with WidgetsBindingObserver {
  DailyActivitySnapshot? _snapshot;
  List<HistoryDay> _history = [];
  ActivityTargets _targets = ActivityTargets();
  bool _loading = true;
  String? _error;
  bool _asked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _asked) {
      _refresh();
    }
  }

  Future<void> _bootstrap() async {
    _targets = await ActivityTargets.load();
    if (!mounted) return;
    setState(() {});
    await _refresh(showPermissionIfEmpty: true);
  }

  Future<void> _enable() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ActivityBridge.requestHealthAuthorization();
    } catch (_) {}
    try {
      await ActivityBridge.requestMotionAuthorization();
    } catch (_) {}
    _asked = true;
    await _refresh(showPermissionIfEmpty: false);
  }

  Future<void> _refresh({bool showPermissionIfEmpty = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snapshot = await ActivityBridge.getDailyActivity();
      final history = await ActivityBridge.getHistory(days: 7);
      if (!mounted) return;
      final hasReading = snapshot.source != 'unavailable';
      setState(() {
        _snapshot = hasReading ? snapshot : _snapshot;
        _history = history;
        _loading = false;
        _asked = showPermissionIfEmpty ? hasReading || _asked : true;
        if (!hasReading && !showPermissionIfEmpty) {
          _error = 'Motion & Fitness is off. Turn it on in Settings, then pull to refresh.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _asked = showPermissionIfEmpty ? _asked : true;
        _error = 'Activity data is unavailable right now.';
      });
    }
  }

  Future<void> _editTargets() async {
    final steps = TextEditingController(text: '${_targets.steps}');
    final distance = TextEditingController(
      text: (_targets.distanceMeters / 1000).toStringAsFixed(1),
    );
    final exercise = TextEditingController(
      text: _targets.exerciseMinutes.toStringAsFixed(0),
    );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Daily targets',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'These are personal goals, not medical advice.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: steps,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Steps'),
              ),
              TextField(
                controller: distance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Distance (km)'),
              ),
              TextField(
                controller: exercise,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Exercise minutes'),
              ),
              const SizedBox(height: 16),
              PillButton(
                label: 'Save targets',
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
      },
    );
    if (saved == true) {
      _targets.steps = int.tryParse(steps.text.trim()) ?? _targets.steps;
      _targets.distanceMeters =
          ((double.tryParse(distance.text.trim()) ?? (_targets.distanceMeters / 1000)) *
                  1000)
              .clamp(0, 100000);
      _targets.exerciseMinutes =
          double.tryParse(exercise.text.trim()) ?? _targets.exerciseMinutes;
      await _targets.save();
      if (mounted) setState(() {});
    }
    steps.dispose();
    distance.dispose();
    exercise.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snapshot;
    final week = _history.length >= 7
        ? _history.sublist(_history.length - 7)
        : _history;

    return AppPage(
      header: PageHeader(
        title: 'Daily activity',
        subtitle: _dateLabel(DateTime.now()),
        onBack: () => Navigator.pop(context),
        trailing: [
          HeaderIconButton(icon: Icons.flag_outlined, onTap: _editTargets),
          HeaderIconButton(
            icon: Icons.refresh_rounded,
            onTap: _asked ? () => _refresh() : _enable,
          ),
        ],
        below: Text(
          snap == null
              ? 'Connect Apple Health and Motion to summarize today’s movement.'
              : '${_formatSteps(snap.steps)} steps · ${formatDistanceKm(snap.distanceMeters ?? 0)}',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.35),
        ),
      ),
      body: _loading && snap == null
                  ? const Center(child: CircularProgressIndicator())
                  : !_asked
                  ? _PermissionPane(onEnable: _enable)
                  : RefreshIndicator(
                      onRefresh: () => _refresh(),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                        children: [
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: AppColors.danger),
                              ),
                            ),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Steps',
                                  value: _formatSteps(snap?.steps),
                                  progress: _progress(snap?.steps?.toDouble(), _targets.steps.toDouble()),
                                  onTap: () => _openMetric('Steps'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Distance',
                                  value: formatDistanceKm(snap?.distanceMeters ?? 0),
                                  progress: _progress(
                                    snap?.distanceMeters,
                                    _targets.distanceMeters,
                                  ),
                                  onTap: () => _openMetric('Distance'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: 'Exercise',
                                  value: snap?.exerciseMinutes == null
                                      ? '—'
                                      : '${snap!.exerciseMinutes!.round()} min',
                                  progress: _progress(
                                    snap?.exerciseMinutes,
                                    _targets.exerciseMinutes,
                                  ),
                                  onTap: () => _openMetric('Exercise'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: 'Flights',
                                  value: snap?.flights == null
                                      ? '—'
                                      : '${snap!.flights!.round()}',
                                  progress: null,
                                  onTap: () => _openMetric('Flights'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Mobility',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          _InfoLine(
                            label: 'Walking speed',
                            value: snap?.walkingSpeedMps == null
                                ? 'Not recorded'
                                : '${(snap!.walkingSpeedMps! * 3.6).toStringAsFixed(1)} km/h',
                          ),
                          _InfoLine(
                            label: 'Step length',
                            value: snap?.stepLengthMeters == null
                                ? 'Not recorded'
                                : '${((snap!.stepLengthMeters!) * 100).toStringAsFixed(0)} cm',
                          ),
                          _InfoLine(
                            label: 'Walking asymmetry',
                            value: snap?.walkingAsymmetry == null
                                ? 'Not recorded'
                                : '${(snap!.walkingAsymmetry! * 100).toStringAsFixed(1)}%',
                          ),
                          _InfoLine(
                            label: 'Double support',
                            value: snap?.doubleSupport == null
                                ? 'Not recorded'
                                : '${(snap!.doubleSupport! * 100).toStringAsFixed(1)}%',
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'This week',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 140,
                            child: week.isEmpty
                                ? const Center(
                                    child: Text(
                                      'No weekly history yet',
                                      style: TextStyle(color: AppColors.muted),
                                    ),
                                  )
                                : _WeekBars(days: week, target: _targets.steps),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'History',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          if (_history.isEmpty)
                            const Text(
                              'Past days appear after Apple Health has step samples.',
                              style: TextStyle(color: AppColors.muted),
                            )
                          else
                            for (final day in _history.reversed.take(14))
                              _InfoLine(
                                label: _dateLabel(day.dayStart),
                                value: _formatSteps(day.steps),
                              ),
                          const SizedBox(height: 18),
                          PillButton(
                            label: 'Outdoor walk, run, hike',
                            onTap: () {
                              Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => const OutdoorHubScreen(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            snap == null
                                ? 'Last updated —'
                                : 'Updated ${_timeLabel(snap.updatedAt)} · ${snap.source}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'HealthKit is the source of truth for daily totals. Core Motion is used only when HealthKit has no sample for that metric. Values are never added together.',
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  void _openMetric(String title) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => MetricDetailScreen(
          title: title,
          history: _history,
          snapshot: _snapshot,
          targets: _targets,
        ),
      ),
    );
  }

  double? _progress(double? value, double target) {
    if (value == null || target <= 0) return null;
    return (value / target).clamp(0, 1);
  }

  String _formatSteps(int? steps) {
    if (steps == null) return '—';
    final s = steps.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  String _dateLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _timeLabel(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _PermissionPane extends StatelessWidget {
  const _PermissionPane({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      children: [
        const Text(
          'See today’s movement',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          'Ajuga reads steps, walking distance, and mobility metrics from Apple Health. Motion & Fitness fills gaps when Health has no sample. Nothing is uploaded.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 22),
        PillButton(label: 'Enable activity access', onTap: onEnable),
        const SizedBox(height: 12),
        PillButton(
          label: 'Skip to outdoor tracking',
          onTap: () {
            Navigator.of(context).push(
              CupertinoPageRoute<void>(builder: (_) => const OutdoorHubScreen()),
            );
          },
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.progress,
    required this.onTap,
  });

  final String label;
  final String value;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
            ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE6E8EF),
                  color: const Color(0xFF2457D6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.days, required this.target});

  final List<HistoryDay> days;
  final int target;

  @override
  Widget build(BuildContext context) {
    final maxSteps = [
      target.toDouble(),
      ...days.map((d) => d.steps.toDouble()),
    ].reduce((a, b) => a > b ? a : b);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final day in days)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: maxSteps == 0 ? 0 : (day.steps / maxSteps).clamp(0.04, 1),
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: day.steps >= target
                                ? const Color(0xFF2457D6)
                                : const Color(0xFFB7C6F0),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        [day.dayStart.weekday - 1],
                    style: const TextStyle(fontSize: 10, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
