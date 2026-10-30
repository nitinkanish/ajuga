import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'heat_log.dart';

const _storeKey = 'ajuga.thermal.v1';
const _seriesKey = 'ajuga.thermal.series.v1';
const _channel = MethodChannel('aster/thermal');
const _events = EventChannel('aster/thermal_events');

class ThermalBridge {
  static Future<PhoneSnapshot> snapshot() async {
    try {
      final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('getThermalState');
      return PhoneSnapshot.fromMap(Map<String, dynamic>.from(raw ?? {}));
    } catch (_) {
      return PhoneSnapshot(at: DateTime.now(), state: 'unknown');
    }
  }

  static Future<String> currentState() async {
    return (await snapshot()).state;
  }

  static Stream<String> get changes {
    return _events.receiveBroadcastStream().map((event) {
      final map = Map<String, dynamic>.from(event as Map);
      return map['state'] as String? ?? 'unknown';
    });
  }
}

class HeatMonitor with WidgetsBindingObserver {
  HeatMonitor._();

  static final instance = HeatMonitor._();

  final _updates = StreamController<HeatView>.broadcast();
  // Held so the thermal listener and sample timer stay alive for the session.
  // ignore: unused_field
  StreamSubscription<String>? _thermalSub;
  // ignore: unused_field
  Timer? _timer;
  bool _started = false;
  List<HeatSample> samples = const [];
  List<PhoneSnapshot> series = const [];
  PhoneSnapshot? latest;

  Stream<HeatView> get updates => _updates.stream;

  HeatView get view => HeatView(latest: latest, series: series, log: samples);

  Future<void> start() async {
    if (_started) return;
    _started = true;
    samples = await HeatStore.load();
    series = await HeatStore.loadSeries();
    WidgetsBinding.instance.addObserver(this);
    _thermalSub = ThermalBridge.changes.listen((_) {
      record(HeatContext.stateChanged);
    });
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      record(HeatContext.whileAjugaOpen);
    });
    await record(HeatContext.ajugaOpen);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      record(HeatContext.leftAjuga);
    } else if (state == AppLifecycleState.resumed) {
      record(HeatContext.returnedToAjuga);
    }
  }

  Future<void> record(HeatContext context) async {
    final reading = await ThermalBridge.snapshot();
    latest = reading;
    final seriesUpdated = appendSeries(series, reading);
    if (!identical(seriesUpdated, series)) {
      series = seriesUpdated;
      await HeatStore.saveSeries(series);
    }
    final next = HeatSample(
      at: reading.at,
      state: reading.state,
      context: context,
      tempC: reading.tempC,
      systemCpu: reading.systemCpu,
      ajugaCpu: reading.ajugaCpu,
    );
    final updated = appendHeatSample(samples, next);
    if (!identical(updated, samples)) {
      samples = updated;
      await HeatStore.save(samples);
    }
    if (!_updates.isClosed) _updates.add(view);
  }

  Future<void> annotate(DateTime at, String note) async {
    samples = [
      for (final sample in samples)
        sample.at == at ? sample.copyWith(note: note) : sample,
    ];
    await HeatStore.save(samples);
    if (!_updates.isClosed) _updates.add(view);
  }

  Future<void> clear() async {
    samples = const [];
    series = const [];
    await HeatStore.save(samples);
    await HeatStore.saveSeries(series);
    if (!_updates.isClosed) _updates.add(view);
  }
}

class HeatView {
  const HeatView({required this.latest, required this.series, required this.log});

  final PhoneSnapshot? latest;
  final List<PhoneSnapshot> series;
  final List<HeatSample> log;
}

class HeatStore {
  static Future<List<HeatSample>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((item) => HeatSample.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<HeatSample> samples) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storeKey,
      jsonEncode(samples.map((sample) => sample.toJson()).toList()),
    );
  }

  static Future<List<PhoneSnapshot>> loadSeries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_seriesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((item) => PhoneSnapshot.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveSeries(List<PhoneSnapshot> points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _seriesKey,
      jsonEncode(points.map((point) => point.toJson()).toList()),
    );
  }
}
