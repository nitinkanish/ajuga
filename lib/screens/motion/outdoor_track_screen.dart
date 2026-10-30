import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../motion/activity_bridge.dart';
import '../../motion/calculations.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/pressable.dart';
import '../../widgets/route_map.dart';
import 'outdoor_summary_screen.dart';

class OutdoorTrackScreen extends StatefulWidget {
  const OutdoorTrackScreen({super.key, required this.activityType});

  final String activityType;

  @override
  State<OutdoorTrackScreen> createState() => _OutdoorTrackScreenState();
}

class _OutdoorTrackScreenState extends State<OutdoorTrackScreen>
    with WidgetsBindingObserver {
  OutdoorSessionState _state = OutdoorSessionState.idle;
  final List<OutdoorPoint> _points = [];
  final List<double> _altitudeDeltas = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  Timer? _ticker;

  late DateTime _startedAt;
  DateTime? _pauseStartedAt;
  double _pausedSeconds = 0;
  double? _currentSpeed;
  double? _relativeAltitude;
  String? _gpsLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _begin();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _begin() async {
    _startedAt = DateTime.now();
    _state = transitionSession(current: _state, action: 'start');
    _sub = ActivityBridge.events.listen(_onEvent);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    await ActivityBridge.startOutdoorSession();
    if (mounted) setState(() {});
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'] as String?;
    if (type == 'location') {
      final sample = GpsSample(
        latitude: (event['latitude'] as num).toDouble(),
        longitude: (event['longitude'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          (event['timestampEpochMs'] as num).toInt(),
        ),
        altitude: (event['altitude'] as num?)?.toDouble(),
        horizontalAccuracy: (event['horizontalAccuracy'] as num?)?.toDouble(),
        speed: (event['speed'] as num?)?.toDouble(),
      );
      final previous = _points.isEmpty ? null : _points.last.toSample();
      final filtered = evaluateGpsSample(sample: sample, previous: previous);
      _gpsLabel = _accuracyLabel(sample.horizontalAccuracy);
      if ((sample.speed ?? -1) >= 0) {
        _currentSpeed = sample.speed;
      }
      if (filtered.accepted) {
        _points.add(
          OutdoorPoint(
            latitude: sample.latitude,
            longitude: sample.longitude,
            timestamp: sample.timestamp,
            altitude: sample.altitude,
            horizontalAccuracy: sample.horizontalAccuracy,
            speed: sample.speed ?? filtered.speed,
          ),
        );
      }
      if (mounted) setState(() {});
    } else if (type == 'altitude') {
      _relativeAltitude = (event['relativeAltitude'] as num?)?.toDouble();
      final deltas = event['deltas'];
      if (deltas is List) {
        _altitudeDeltas
          ..clear()
          ..addAll(deltas.map((e) => (e as num).toDouble()));
      }
      if (mounted) setState(() {});
    } else if (type == 'error') {
      _gpsLabel = 'GPS error';
      if (mounted) setState(() {});
    }
  }

  String _accuracyLabel(double? accuracy) {
    if (accuracy == null || accuracy < 0) return 'GPS waiting';
    if (accuracy <= 10) return 'GPS strong · ${accuracy.toStringAsFixed(0)} m';
    if (accuracy <= 25) return 'GPS ok · ${accuracy.toStringAsFixed(0)} m';
    return 'GPS weak · ${accuracy.toStringAsFixed(0)} m';
  }

  Duration get _elapsed {
    final raw = DateTime.now().difference(_startedAt);
    var paused = _pausedSeconds;
    if (_state == OutdoorSessionState.paused && _pauseStartedAt != null) {
      paused += DateTime.now().difference(_pauseStartedAt!).inMilliseconds / 1000.0;
    }
    final ms = raw.inMilliseconds - (paused * 1000).round();
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  SessionSummaryStats get _liveSummary {
    return summarizeSession(
      samples: _points.map((p) => p.toSample()).toList(),
      startedAt: _startedAt,
      finishedAt: DateTime.now(),
      pausedDuration: Duration(milliseconds: (_pausedSeconds * 1000).round()),
      relativeAltitudeDeltas: _altitudeDeltas.isEmpty ? null : _altitudeDeltas,
    );
  }

  Future<void> _pause() async {
    _pauseStartedAt = DateTime.now();
    _state = transitionSession(current: _state, action: 'pause');
    await ActivityBridge.pauseOutdoorSession();
    setState(() {});
  }

  Future<void> _resume() async {
    if (_pauseStartedAt != null) {
      _pausedSeconds +=
          DateTime.now().difference(_pauseStartedAt!).inMilliseconds / 1000.0;
      _pauseStartedAt = null;
    }
    _state = transitionSession(current: _state, action: 'resume');
    await ActivityBridge.resumeOutdoorSession();
    setState(() {});
  }

  Future<void> _finish() async {
    if (_pauseStartedAt != null) {
      _pausedSeconds +=
          DateTime.now().difference(_pauseStartedAt!).inMilliseconds / 1000.0;
      _pauseStartedAt = null;
    }
    final stop = await ActivityBridge.stopOutdoorSession();
    final deltas = stop['relativeAltitudeDeltas'];
    if (deltas is List) {
      _altitudeDeltas
        ..clear()
        ..addAll(deltas.map((e) => (e as num).toDouble()));
    }
    _state = transitionSession(current: _state, action: 'finish');
    final session = OutdoorSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      activityType: widget.activityType,
      startedAt: _startedAt,
      finishedAt: DateTime.now(),
      pausedSeconds: _pausedSeconds,
      points: List.of(_points),
      relativeAltitudeDeltas: List.of(_altitudeDeltas),
      status: 'finished',
    );
    await ActivityBridge.saveSession(session);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      CupertinoPageRoute<void>(
        builder: (_) => OutdoorSummaryScreen(session: session),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (_state == OutdoorSessionState.idle || _points.isEmpty) {
      await ActivityBridge.stopOutdoorSession();
      return true;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Discard this session?'),
          content: const Text(
            'The unfinished route will not be saved.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep tracking'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        );
      },
    );
    if (ok == true) {
      await ActivityBridge.stopOutdoorSession();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final summary = _liveSummary;
    final tracking = _state == OutdoorSessionState.tracking;
    final paused = _state == OutdoorSessionState.paused;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldLeave = await _confirmDiscard();
        if (shouldLeave && mounted) {
          Navigator.of(this.context).pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: lightStatus,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                  child: Row(
                    children: [
                      HeaderIconButton(
                        light: true,
                        icon: Icons.close_rounded,
                        onTap: () async {
                          final shouldLeave = await _confirmDiscard();
                          if (shouldLeave && mounted) {
                            Navigator.of(this.context).pop();
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.activityType[0].toUpperCase() +
                            widget.activityType.substring(1),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tracking
                              ? const Color(0xFFE7F8F0)
                              : const Color(0xFFFFF4E5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tracking ? 'Tracking' : 'Paused',
                          style: TextStyle(
                            color: tracking
                                ? AppColors.positive
                                : const Color(0xFFB7791F),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: RouteMap(
                      points: _points,
                      followUser: tracking,
                      height: MediaQuery.sizeOf(context).height * 0.42,
                    ),
                  ),
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppColors.line)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        formatDuration(_elapsed),
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _gpsLabel ?? 'Acquiring GPS…',
                        style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _LiveStat(
                              label: 'Distance',
                              value: formatDistanceKm(summary.distanceMeters),
                            ),
                          ),
                          Expanded(
                            child: _LiveStat(
                              label: 'Pace',
                              value: formatPace(
                                paceSecondsPerKm(
                                  _currentSpeed != null && _currentSpeed! > 0
                                      ? _currentSpeed!
                                      : summary.avgSpeedMps,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _LiveStat(
                              label: 'Elev. gain*',
                              value:
                                  '${summary.elevation.gainMeters.toStringAsFixed(0)} m',
                            ),
                          ),
                        ],
                      ),
                      if (_relativeAltitude != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Relative altitude ${_relativeAltitude!.toStringAsFixed(1)} m · approx.',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (tracking)
                            Expanded(
                              child: PillButton(label: 'Pause', onTap: _pause),
                            ),
                          if (paused)
                            Expanded(
                              child: PillButton(label: 'Resume', onTap: _resume),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PillButton(label: 'Finish', onTap: _finish),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '*Elevation gain is estimated from filtered GPS or barometer relative altitude.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ],
    );
  }
}
