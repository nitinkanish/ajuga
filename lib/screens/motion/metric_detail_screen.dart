import 'package:flutter/material.dart';

import '../../motion/activity_bridge.dart';
import '../../motion/activity_targets.dart';
import '../../motion/calculations.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';

class MetricDetailScreen extends StatelessWidget {
  const MetricDetailScreen({
    super.key,
    required this.title,
    required this.history,
    required this.snapshot,
    required this.targets,
  });

  final String title;
  final List<HistoryDay> history;
  final DailyActivitySnapshot? snapshot;
  final ActivityTargets targets;

  @override
  Widget build(BuildContext context) {
    final week = history.length >= 7 ? history.sublist(history.length - 7) : history;
    final month = history;
    final weekAvg = week.isEmpty
        ? 0.0
        : week.map((d) => d.steps).reduce((a, b) => a + b) / week.length;
    final monthAvg = month.isEmpty
        ? 0.0
        : month.map((d) => d.steps).reduce((a, b) => a + b) / month.length;

    return AppPage(
      header: PageHeader(
        title: title,
        subtitle: _todayValue(),
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  _Stat(label: 'Today', value: _todayValue()),
                  _Stat(label: '7-day average steps', value: weekAvg.round().toString()),
                  _Stat(label: '30-day average steps', value: monthAvg.round().toString()),
                  if (title == 'Steps')
                    _Stat(label: 'Daily target', value: '${targets.steps}'),
                  if (title == 'Distance')
                    _Stat(
                      label: 'Daily target',
                      value: formatDistanceKm(targets.distanceMeters),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Trends use Apple Health step history when available. Other metrics show today’s sample only.',
                    style: TextStyle(color: AppColors.muted, height: 1.4, fontSize: 13),
                  ),
                ],
      ),
    );
  }

  String _todayValue() {
    final snap = snapshot;
    switch (title) {
      case 'Steps':
        return snap?.steps?.toString() ?? '—';
      case 'Distance':
        return formatDistanceKm(snap?.distanceMeters ?? 0);
      case 'Exercise':
        return snap?.exerciseMinutes == null
            ? '—'
            : '${snap!.exerciseMinutes!.round()} min';
      case 'Flights':
        return snap?.flights == null ? '—' : '${snap!.flights!.round()}';
      default:
        return '—';
    }
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      ),
    );
  }
}
