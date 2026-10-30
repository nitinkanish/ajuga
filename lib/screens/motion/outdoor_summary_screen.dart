import 'package:flutter/material.dart';

import '../../motion/activity_bridge.dart';
import '../../motion/calculations.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/route_map.dart';

class OutdoorSummaryScreen extends StatelessWidget {
  const OutdoorSummaryScreen({super.key, required this.session});

  final OutdoorSession session;

  @override
  Widget build(BuildContext context) {
    final summary = session.summary;
    final poorSamples = session.points
        .where((p) => (p.horizontalAccuracy ?? 999) > 25)
        .length;
    final qualityNote = session.points.isEmpty
        ? 'No accepted GPS points were recorded.'
        : poorSamples > session.points.length / 2
        ? 'GPS quality was weak for much of this session. Distance and elevation are approximate.'
        : null;

    final title = '${session.activityType[0].toUpperCase()}${session.activityType.substring(1)} summary';
    return AppPage(
      header: PageHeader(
        title: title,
        subtitle: '${_clock(session.startedAt)} → ${_clock(session.finishedAt ?? session.startedAt)}',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
                children: [
                  RouteMap(points: session.points, height: 240),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Row(
                          label: 'Distance',
                          value: formatDistanceKm(summary.distanceMeters),
                        ),
                        _Row(
                          label: 'Duration',
                          value: formatDuration(
                            Duration(seconds: summary.elapsedSeconds.round()),
                          ),
                        ),
                        _Row(
                          label: 'Moving time',
                          value: formatDuration(
                            Duration(seconds: summary.movingSeconds.round()),
                          ),
                        ),
                        _Row(
                          label: 'Average pace',
                          value: formatPace(summary.avgPaceSecPerKm),
                        ),
                        _Row(
                          label: 'Average speed',
                          value:
                              '${(summary.avgSpeedMps * 3.6).toStringAsFixed(1)} km/h',
                        ),
                        _Row(
                          label: 'Est. elevation gain',
                          value:
                              '${summary.elevation.gainMeters.toStringAsFixed(0)} m (${summary.elevation.source})',
                        ),
                        _Row(
                          label: 'Est. elevation loss',
                          value:
                              '${summary.elevation.lossMeters.toStringAsFixed(0)} m',
                        ),
                        _Row(
                          label: 'Route points',
                          value: '${session.points.length}',
                        ),
                        if (qualityNote != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            qualityNote,
                            style: const TextStyle(
                              color: Color(0xFFB7791F),
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        const Text(
                          'This session is stored only on this iPhone.',
                          style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
      ),
    );
  }

  String _clock(DateTime d) {
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
