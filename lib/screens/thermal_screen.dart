import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../thermal/heat_log.dart';
import '../../thermal/heat_monitor.dart';
import '../../widgets/app_header.dart';
import '../../widgets/pressable.dart';
import 'lifeos/life_chrome.dart';

class ThermalScreen extends StatefulWidget {
  const ThermalScreen({super.key});

  @override
  State<ThermalScreen> createState() => _ThermalScreenState();
}

class _ThermalScreenState extends State<ThermalScreen> {
  HeatView _view = const HeatView(latest: null, series: [], log: []);
  StreamSubscription<HeatView>? _sub;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _view = HeatMonitor.instance.view;
    _sub = HeatMonitor.instance.updates.listen((view) {
      if (!mounted) return;
      setState(() => _view = view);
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      HeatMonitor.instance.record(HeatContext.whileAjugaOpen);
    });
    HeatMonitor.instance.record(HeatContext.whileAjugaOpen);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _note(HeatSample sample) async {
    final controller = TextEditingController(text: sample.note);
    final saved = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Which app was open?'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Optional note, stays on this iPhone'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
          ],
        );
      },
    );
    controller.dispose();
    if (saved == null) return;
    await HeatMonitor.instance.annotate(sample.at, saved);
  }

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    final latest = _view.latest;
    final state = latest?.state ?? 'unknown';
    final delta = temperatureChange(_view.series);
    final away = awayHeatNote(_view.log);
    return AppPage(
      background: colors.sheet,
      header: PageHeader(
        title: 'Phone heat',
        onBack: () => Navigator.pop(context),
        below: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              latest?.tempC == null ? 'Thermal level' : 'Battery sensor',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              latest?.tempC == null ? heatLabel(state) : '${latest!.tempC!.toStringAsFixed(1)}°C',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w700,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              latest?.tempC == null ? heatMeaning(state) : '${heatLabel(state)} · ${heatMeaning(state)}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.82), height: 1.35),
            ),
          ],
        ),
      ),
      body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                children: [
                  if (latest != null)
                    Text(
                      heatDiagnosis(latest, tempDelta: delta),
                      style: TextStyle(color: colors.ink, height: 1.4),
                    ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _Stat(
                        label: 'Phone processor',
                        value: latest?.systemCpu == null ? 'Measuring' : '${(latest!.systemCpu! * 100).round()}%',
                        caption: 'All cores busy',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _Stat(
                        label: 'Ajuga',
                        value: latest?.ajugaCpu == null ? 'Measuring' : '${(latest!.ajugaCpu! * 100).round()}%',
                        caption: 'Of one core',
                      )),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _Stat(
                        label: 'Power',
                        value: _power(latest),
                        caption: latest?.lowPower == true ? 'Low Power Mode on' : 'Low Power Mode off',
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: _Stat(
                        label: 'Battery',
                        value: latest?.batteryLevel == null ? '—' : '${(latest!.batteryLevel! * 100).round()}%',
                        caption: _battery(latest?.battery),
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Apps using the processor', style: TextStyle(color: colors.ink, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (latest == null || latest.apps.isEmpty)
                    Text(
                      'Stay on this screen for a few seconds. Ajuga lists apps whose processor time it can measure. If none appear, iOS is hiding the other apps.',
                      style: TextStyle(color: colors.muted, height: 1.4),
                    )
                  else
                    LifeCard(
                      child: Column(
                        children: [
                          for (final app in latest.apps)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      app.isAjuga ? '${app.name} (this app)' : app.name,
                                      style: TextStyle(color: colors.ink, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  Text(
                                    '${(app.cpu * 100).round()}%',
                                    style: TextStyle(color: colors.ink, fontFeatures: const [FontFeature.tabularFigures()]),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text('Temperature', style: TextStyle(color: colors.ink, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  LifeCard(
                    child: SizedBox(
                      height: 160,
                      width: double.infinity,
                      child: _HeatGraph(points: _view.series),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The line is the battery temperature when iOS allows that sensor. Otherwise it is the thermal level. iOS does not name another app’s energy use.',
                    style: TextStyle(color: colors.muted, fontSize: 12, height: 1.35),
                  ),
                  if (away != null) ...[
                    const SizedBox(height: 12),
                    LifeCard(child: Text(away, style: TextStyle(color: colors.ink, height: 1.4))),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text('Log', style: TextStyle(color: colors.ink, fontSize: 18, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_view.log.isNotEmpty)
                        Pressable(
                          onTap: HeatMonitor.instance.clear,
                          child: const Text('Clear', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_view.log.isEmpty)
                    Text(
                      'Leave Ajuga, use another app, then come back. The log keeps the heat level, temperature, and processor load.',
                      style: TextStyle(color: colors.muted, height: 1.4),
                    )
                  else
                    for (final sample in _view.log)
                      Pressable(
                        onTap: () => _note(sample),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${heatLabel(sample.state)} · ${heatContextLabel(sample.context)}',
                                style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700),
                              ),
                              Text(_detail(sample), style: TextStyle(color: colors.muted, height: 1.35)),
                              if (sample.note.isNotEmpty)
                                Text(sample.note, style: TextStyle(color: colors.ink)),
                            ],
                          ),
                        ),
                      ),
                ],
      ),
    );
  }

  String _power(PhoneSnapshot? latest) {
    if (latest == null) return '—';
    if (latest.battery == 'charging') return 'Charging';
    if (latest.battery == 'full') return 'Plugged in';
    if (latest.battery == 'unplugged') return 'Unplugged';
    return 'Unknown';
  }

  String _battery(String? battery) {
    switch (battery) {
      case 'charging':
        return 'Charging adds heat';
      case 'full':
        return 'Full and connected';
      case 'unplugged':
        return 'On battery';
      default:
        return 'Battery state unknown';
    }
  }

  String _detail(HeatSample sample) {
    final parts = <String>[
      '${sample.at.day}/${sample.at.month} ${sample.at.hour.toString().padLeft(2, '0')}:${sample.at.minute.toString().padLeft(2, '0')}',
    ];
    if (sample.tempC != null) parts.add('${sample.tempC!.toStringAsFixed(1)}°C');
    if (sample.systemCpu != null) parts.add('phone ${(sample.systemCpu! * 100).round()}%');
    if (sample.ajugaCpu != null) parts.add('Ajuga ${(sample.ajugaCpu! * 100).round()}%');
    return parts.join(' · ');
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.caption});

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

class _HeatGraph extends StatelessWidget {
  const _HeatGraph({required this.points});

  final List<PhoneSnapshot> points;

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    if (points.length < 2) {
      return Center(
        child: Text(
          'Collecting readings. Stay on this screen for a few seconds.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.muted, height: 1.35),
        ),
      );
    }
    return CustomPaint(
      painter: _HeatPainter(points: points, ink: colors.ink, muted: colors.muted),
      child: const SizedBox.expand(),
    );
  }
}

class _HeatPainter extends CustomPainter {
  _HeatPainter({required this.points, required this.ink, required this.muted});

  final List<PhoneSnapshot> points;
  final Color ink;
  final Color muted;

  @override
  void paint(Canvas canvas, Size size) {
    final temps = points.map((point) => point.tempC).whereType<double>().toList();
    final useTemp = temps.length >= 2;
    final values = useTemp
        ? points.map((point) => point.tempC).toList()
        : points.map((point) => _level(point.state)).toList();
    final known = values.whereType<double>().toList();
    if (known.length < 2) return;
    var minValue = known.reduce(math.min);
    var maxValue = known.reduce(math.max);
    if ((maxValue - minValue).abs() < 0.4) {
      minValue -= 0.5;
      maxValue += 0.5;
    }
    final line = Paint()
      ..color = const Color(0xFF2457D6)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path();
    var started = false;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;
      final x = values.length == 1 ? size.width / 2 : size.width * i / (values.length - 1);
      final y = size.height - ((value - minValue) / (maxValue - minValue)) * (size.height - 18) - 4;
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, line);
    final label = TextPainter(
      text: TextSpan(
        text: useTemp
            ? '${minValue.toStringAsFixed(1)}–${maxValue.toStringAsFixed(1)}°C'
            : 'Cool to very hot',
        style: TextStyle(color: muted, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(0, size.height - label.height));
    canvas.drawCircle(
      Offset(size.width - 4, _y(values.last, minValue, maxValue, size)),
      4,
      Paint()..color = ink,
    );
  }

  double _y(double? value, double minValue, double maxValue, Size size) {
    if (value == null) return size.height / 2;
    return size.height - ((value - minValue) / (maxValue - minValue)) * (size.height - 18) - 4;
  }

  double _level(String state) {
    switch (state) {
      case 'fair':
        return 1;
      case 'serious':
        return 2;
      case 'critical':
        return 3;
      default:
        return 0;
    }
  }

  @override
  bool shouldRepaint(covariant _HeatPainter oldDelegate) => oldDelegate.points != points;
}
