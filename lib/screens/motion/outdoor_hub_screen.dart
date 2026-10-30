import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../motion/activity_bridge.dart';
import '../../motion/calculations.dart';
import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/pressable.dart';
import 'outdoor_summary_screen.dart';
import 'outdoor_track_screen.dart';

class OutdoorHubScreen extends StatefulWidget {
  const OutdoorHubScreen({super.key});

  @override
  State<OutdoorHubScreen> createState() => _OutdoorHubScreenState();
}

class _OutdoorHubScreenState extends State<OutdoorHubScreen> {
  List<OutdoorSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final sessions = await ActivityBridge.loadSessions();
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _start(String type) async {
    final auth = await ActivityBridge.requestLocationAuthorization(always: true);
    final status = auth['status'] as String? ?? '';
    if (status == 'denied' || status == 'restricted') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location access is required to track an outdoor session.'),
        ),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => OutdoorTrackScreen(activityType: type),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      header: PageHeader(
        title: 'Outdoor',
        subtitle: 'GPS route, pace, and estimated elevation stay on this iPhone.',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  const Text(
                    'Start a session',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _StartTile(
                    title: 'Walk',
                    subtitle: 'City walks and casual routes',
                    icon: Icons.directions_walk_rounded,
                    onTap: () => _start('walk'),
                  ),
                  _StartTile(
                    title: 'Run',
                    subtitle: 'Road or trail running',
                    icon: Icons.directions_run_rounded,
                    onTap: () => _start('run'),
                  ),
                  _StartTile(
                    title: 'Hike',
                    subtitle: 'Elevation-aware outdoor hikes',
                    icon: Icons.terrain_rounded,
                    onTap: () => _start('hike'),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'History',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_sessions.isEmpty)
                    const Text(
                      'Finished outdoor sessions appear here.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else
                    for (final session in _sessions)
                      Pressable(
                        onTap: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute<void>(
                              builder: (_) => OutdoorSummaryScreen(session: session),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF3F5FA),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(_iconFor(session.activityType), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      session.activityType[0].toUpperCase() +
                                          session.activityType.substring(1),
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      '${_when(session.startedAt)} · ${formatDistanceKm(session.summary.distanceMeters)}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                formatDuration(
                                  Duration(
                                    seconds: session.summary.elapsedSeconds.round(),
                                  ),
                                ),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'run':
        return Icons.directions_run_rounded;
      case 'hike':
        return Icons.terrain_rounded;
      default:
        return Icons.directions_walk_rounded;
    }
  }

  String _when(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _StartTile extends StatelessWidget {
  const _StartTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
