enum HeatContext {
  ajugaOpen,
  whileAjugaOpen,
  stateChanged,
  leftAjuga,
  returnedToAjuga,
}

class HeatSample {
  const HeatSample({
    required this.at,
    required this.state,
    required this.context,
    this.note = '',
    this.tempC,
    this.systemCpu,
    this.ajugaCpu,
  });

  final DateTime at;
  final String state;
  final HeatContext context;
  final String note;
  final double? tempC;
  final double? systemCpu;
  final double? ajugaCpu;

  HeatSample copyWith({String? note}) {
    return HeatSample(
      at: at,
      state: state,
      context: context,
      note: note ?? this.note,
      tempC: tempC,
      systemCpu: systemCpu,
      ajugaCpu: ajugaCpu,
    );
  }

  Map<String, dynamic> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'state': state,
        'context': context.name,
        'note': note,
        'tempC': tempC,
        'systemCpu': systemCpu,
        'ajugaCpu': ajugaCpu,
      };

  factory HeatSample.fromJson(Map<String, dynamic> json) {
    final name = json['context'] as String? ?? HeatContext.whileAjugaOpen.name;
    return HeatSample(
      at: DateTime.fromMillisecondsSinceEpoch((json['at'] as num).toInt()),
      state: json['state'] as String? ?? 'unknown',
      context: HeatContext.values.firstWhere(
        (value) => value.name == name,
        orElse: () => HeatContext.whileAjugaOpen,
      ),
      note: json['note'] as String? ?? '',
      tempC: (json['tempC'] as num?)?.toDouble(),
      systemCpu: (json['systemCpu'] as num?)?.toDouble(),
      ajugaCpu: (json['ajugaCpu'] as num?)?.toDouble(),
    );
  }
}

class AppLoad {
  const AppLoad({required this.name, required this.cpu, this.isAjuga = false});

  final String name;
  final double cpu;
  final bool isAjuga;

  Map<String, dynamic> toJson() => {'name': name, 'cpu': cpu, 'isAjuga': isAjuga};

  factory AppLoad.fromJson(Map<String, dynamic> json) {
    return AppLoad(
      name: json['name'] as String? ?? 'App',
      cpu: (json['cpu'] as num?)?.toDouble() ?? 0,
      isAjuga: json['isAjuga'] == true,
    );
  }
}

class PhoneSnapshot {
  const PhoneSnapshot({
    required this.at,
    required this.state,
    this.tempC,
    this.systemCpu,
    this.ajugaCpu,
    this.battery = 'unknown',
    this.batteryLevel,
    this.lowPower = false,
    this.apps = const [],
  });

  final DateTime at;
  final String state;
  final double? tempC;
  final double? systemCpu;
  final double? ajugaCpu;
  final String battery;
  final double? batteryLevel;
  final bool lowPower;
  final List<AppLoad> apps;

  Map<String, dynamic> toJson() => {
        'at': at.millisecondsSinceEpoch,
        'state': state,
        'tempC': tempC,
        'systemCpu': systemCpu,
        'ajugaCpu': ajugaCpu,
        'battery': battery,
        'batteryLevel': batteryLevel,
        'lowPower': lowPower,
        'apps': apps.map((app) => app.toJson()).toList(),
      };

  factory PhoneSnapshot.fromJson(Map<String, dynamic> json) {
    return PhoneSnapshot(
      at: DateTime.fromMillisecondsSinceEpoch((json['at'] as num).toInt()),
      state: json['state'] as String? ?? 'unknown',
      tempC: (json['tempC'] as num?)?.toDouble(),
      systemCpu: (json['systemCpu'] as num?)?.toDouble(),
      ajugaCpu: (json['ajugaCpu'] as num?)?.toDouble(),
      battery: json['battery'] as String? ?? 'unknown',
      batteryLevel: (json['batteryLevel'] as num?)?.toDouble(),
      lowPower: json['lowPower'] as bool? ?? false,
      apps: _appsFrom(json['apps']),
    );
  }

  factory PhoneSnapshot.fromMap(Map<String, dynamic> map) {
    final rawTemp = (map['tempC'] as num?)?.toDouble();
    return PhoneSnapshot(
      at: DateTime.fromMillisecondsSinceEpoch(
        (map['capturedAtEpochMs'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      state: map['state'] as String? ?? 'unknown',
      tempC: rawTemp != null && rawTemp >= 5 && rawTemp <= 70 ? rawTemp : null,
      systemCpu: _unit((map['systemCpu'] as num?)?.toDouble()),
      ajugaCpu: _nonNegative((map['ajugaCpu'] as num?)?.toDouble()),
      battery: map['battery'] as String? ?? 'unknown',
      batteryLevel: _unit((map['batteryLevel'] as num?)?.toDouble()),
      lowPower: map['lowPower'] == true,
      apps: _appsFrom(map['apps']),
    );
  }
}

List<AppLoad> _appsFrom(Object? raw) {
  if (raw is! List) return const [];
  final apps = <AppLoad>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final app = AppLoad.fromJson(item.cast<String, dynamic>());
    if (app.name.isEmpty || app.cpu < 0 || app.cpu > 8) continue;
    apps.add(app);
  }
  apps.sort((a, b) => b.cpu.compareTo(a.cpu));
  return apps;
}

/// Highest processor use that is not Ajuga. Null when iOS did not reveal one.
AppLoad? busiestOtherApp(List<AppLoad> apps) {
  AppLoad? best;
  for (final app in apps) {
    if (app.isAjuga || app.cpu < 0.05) continue;
    if (best == null || app.cpu > best.cpu) best = app;
  }
  return best;
}

double? _unit(double? value) {
  if (value == null || value < 0 || value > 1) return null;
  return value;
}

double? _nonNegative(double? value) {
  if (value == null || value < 0 || value > 8) return null;
  return value;
}

const seriesLimit = 240;

List<PhoneSnapshot> appendSeries(List<PhoneSnapshot> points, PhoneSnapshot next) {
  if (points.isNotEmpty && next.at.difference(points.last.at).inSeconds < 4) {
    return points;
  }
  final updated = [...points, next];
  if (updated.length <= seriesLimit) return updated;
  return updated.sublist(updated.length - seriesLimit);
}

double? temperatureChange(List<PhoneSnapshot> points) {
  final temps = points.map((point) => point.tempC).whereType<double>().toList();
  if (temps.length < 2) return null;
  return temps.last - temps.first;
}

String heatDiagnosis(PhoneSnapshot now, {double? tempDelta}) {
  final lines = <String>[];
  if (now.tempC != null) {
    lines.add('The battery sensor reads ${now.tempC!.toStringAsFixed(1)}°C right now.');
  } else {
    lines.add('A degree reading is not available. The thermal level is ${heatLabel(now.state)}.');
  }
  if (now.battery == 'charging') {
    lines.add('The phone is charging, and charging adds heat.');
  } else if (now.battery == 'full') {
    lines.add('The battery is full and still plugged in.');
  }
  if (now.systemCpu != null) {
    lines.add('The whole phone is using about ${(now.systemCpu! * 100).round()}% of its processors.');
  }
  if (now.ajugaCpu != null) {
    lines.add('Ajuga itself is using about ${(now.ajugaCpu! * 100).round()}% of one core.');
  }
  final other = busiestOtherApp(now.apps);
  if (other != null) {
    lines.add(
      '${other.name} is using about ${(other.cpu * 100).round()}% of one core, the highest use outside Ajuga. That can warm the phone. Processor time is not itself a temperature.',
    );
  } else if (now.systemCpu != null && now.ajugaCpu != null && now.systemCpu! >= 0.35 && now.ajugaCpu! < 0.2) {
    lines.add('Most of that work is outside Ajuga. iOS did not reveal which app it is.');
  } else if (now.ajugaCpu != null && now.ajugaCpu! >= 0.5) {
    lines.add('Ajuga is a large part of the current processor load.');
  } else if ((now.state == 'serious' || now.state == 'critical' || (now.tempC != null && now.tempC! >= 38)) &&
      (now.systemCpu == null || now.systemCpu! < 0.25)) {
    lines.add('The phone is warm while the processor looks fairly idle. Sunlight, a case, or recent work can do that.');
  }
  if (tempDelta != null && tempDelta >= 0.4) {
    lines.add('Across this graph the sensor rose ${tempDelta.toStringAsFixed(1)}°C.');
  } else if (tempDelta != null && tempDelta <= -0.4) {
    lines.add('Across this graph the sensor fell ${(-tempDelta).toStringAsFixed(1)}°C.');
  }
  return lines.join(' ');
}

const heatLogLimit = 200;

String heatLabel(String state) {
  switch (state) {
    case 'nominal':
      return 'Cool';
    case 'fair':
      return 'Warm';
    case 'serious':
      return 'Hot';
    case 'critical':
      return 'Very hot';
    default:
      return 'Unknown';
  }
}

String heatMeaning(String state) {
  switch (state) {
    case 'nominal':
      return 'The thermal sensors are within the normal range.';
    case 'fair':
      return 'The phone is warmer than usual. iOS may slow some work slightly.';
    case 'serious':
      return 'The phone is hot. iOS is reducing performance to cool it down.';
    case 'critical':
      return 'The phone is very hot. iOS is protecting the device.';
    default:
      return 'The thermal reading is not available.';
  }
}

String heatContextLabel(HeatContext context) {
  switch (context) {
    case HeatContext.ajugaOpen:
      return 'Opened Ajuga';
    case HeatContext.whileAjugaOpen:
      return 'While Ajuga was open';
    case HeatContext.stateChanged:
      return 'Heat level changed';
    case HeatContext.leftAjuga:
      return 'Left Ajuga';
    case HeatContext.returnedToAjuga:
      return 'Returned to Ajuga';
  }
}

bool shouldKeepHeatSample(HeatSample? previous, HeatSample next) {
  if (previous == null) return true;
  if (previous.state != next.state) return true;
  final boundary = next.context == HeatContext.leftAjuga || next.context == HeatContext.returnedToAjuga;
  if (boundary) {
    if (previous.context == next.context && next.at.difference(previous.at).inSeconds < 20) {
      return false;
    }
    return true;
  }
  return next.at.difference(previous.at) >= const Duration(minutes: 15);
}

List<HeatSample> appendHeatSample(List<HeatSample> samples, HeatSample next) {
  final newest = samples.isEmpty ? null : samples.first;
  if (!shouldKeepHeatSample(newest, next)) return samples;
  return [next, ...samples].take(heatLogLimit).toList();
}

/// Compares the latest return with the leave that happened just before it.
String? awayHeatNote(List<HeatSample> newestFirst) {
  HeatSample? returned;
  for (final sample in newestFirst) {
    if (sample.context == HeatContext.returnedToAjuga) {
      returned = sample;
      break;
    }
  }
  if (returned == null) return null;
  HeatSample? left;
  for (final sample in newestFirst) {
    if (sample.at.isBefore(returned.at) && sample.context == HeatContext.leftAjuga) {
      left = sample;
      break;
    }
  }
  if (left == null) return null;
  if (left.state == returned.state) {
    return 'After you left Ajuga, the phone was still ${heatLabel(returned.state).toLowerCase()}. iOS does not name the other app.';
  }
  return 'After you left Ajuga, heat went from ${heatLabel(left.state)} to ${heatLabel(returned.state)}. iOS does not name the other app.';
}
