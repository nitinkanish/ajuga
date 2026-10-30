import 'dart:convert';

class TimeSpan {
  const TimeSpan({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  bool get valid => end.isAfter(start);
}

enum ValueKind { measured, derived, estimated, manual, unavailable }

class Reading {
  const Reading.measured(this.value, {required this.source})
      : kind = ValueKind.measured;

  const Reading.unavailable(this.source)
      : value = null,
        kind = ValueKind.unavailable;

  const Reading({
    required this.value,
    required this.kind,
    required this.source,
  });

  final double? value;
  final ValueKind kind;
  final String source;

  bool get known => value != null && kind != ValueKind.unavailable;
}

class CheckIn {
  const CheckIn({
    required this.id,
    required this.at,
    required this.energy,
    required this.mood,
    required this.focus,
    required this.stress,
    this.note = '',
    this.tags = const [],
  });

  final String id;
  final DateTime at;
  final int energy;
  final int mood;
  final int focus;
  final int stress;
  final String note;
  final List<String> tags;

  CheckIn copyWith({String? note, List<String>? tags}) {
    return CheckIn(
      id: id,
      at: at,
      energy: energy,
      mood: mood,
      focus: focus,
      stress: stress,
      note: note ?? this.note,
      tags: tags ?? this.tags,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.millisecondsSinceEpoch,
        'energy': energy,
        'mood': mood,
        'focus': focus,
        'stress': stress,
        'note': note,
        'tags': tags,
      };

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      id: json['id'] as String,
      at: DateTime.fromMillisecondsSinceEpoch((json['at'] as num).toInt()),
      energy: (json['energy'] as num).toInt(),
      mood: (json['mood'] as num).toInt(),
      focus: (json['focus'] as num).toInt(),
      stress: (json['stress'] as num).toInt(),
      note: json['note'] as String? ?? '',
      tags: ((json['tags'] as List?) ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class LifeNote {
  const LifeNote({
    required this.id,
    required this.at,
    required this.text,
  });

  final String id;
  final DateTime at;
  final String text;

  Map<String, dynamic> toJson() => {
        'id': id,
        'at': at.millisecondsSinceEpoch,
        'text': text,
      };

  factory LifeNote.fromJson(Map<String, dynamic> json) {
    return LifeNote(
      id: json['id'] as String,
      at: DateTime.fromMillisecondsSinceEpoch((json['at'] as num).toInt()),
      text: json['text'] as String? ?? '',
    );
  }
}

class FocusRecord {
  const FocusRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.plannedSeconds,
    required this.elapsedSeconds,
    this.rating,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedSeconds;
  final int elapsedSeconds;
  final int? rating;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startedAt': startedAt.millisecondsSinceEpoch,
        'endedAt': endedAt.millisecondsSinceEpoch,
        'plannedSeconds': plannedSeconds,
        'elapsedSeconds': elapsedSeconds,
        'rating': rating,
      };

  factory FocusRecord.fromJson(Map<String, dynamic> json) {
    return FocusRecord(
      id: json['id'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch((json['startedAt'] as num).toInt()),
      endedAt: DateTime.fromMillisecondsSinceEpoch((json['endedAt'] as num).toInt()),
      plannedSeconds: (json['plannedSeconds'] as num).toInt(),
      elapsedSeconds: (json['elapsedSeconds'] as num).toInt(),
      rating: (json['rating'] as num?)?.toInt(),
    );
  }
}

class LifeSettings {
  const LifeSettings({
    this.calendarEnabled = false,
    this.remindersEnabled = false,
    this.reviewWeekday = DateTime.sunday,
    this.reviewHour = 18,
    this.reviewMinute = 0,
    this.minimumObservations = 5,
  });

  final bool calendarEnabled;
  final bool remindersEnabled;
  final int reviewWeekday;
  final int reviewHour;
  final int reviewMinute;
  final int minimumObservations;

  LifeSettings copyWith({
    bool? calendarEnabled,
    bool? remindersEnabled,
    int? reviewWeekday,
    int? reviewHour,
    int? reviewMinute,
    int? minimumObservations,
  }) {
    return LifeSettings(
      calendarEnabled: calendarEnabled ?? this.calendarEnabled,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reviewWeekday: reviewWeekday ?? this.reviewWeekday,
      reviewHour: reviewHour ?? this.reviewHour,
      reviewMinute: reviewMinute ?? this.reviewMinute,
      minimumObservations: minimumObservations ?? this.minimumObservations,
    );
  }

  Map<String, dynamic> toJson() => {
        'calendarEnabled': calendarEnabled,
        'remindersEnabled': remindersEnabled,
        'reviewWeekday': reviewWeekday,
        'reviewHour': reviewHour,
        'reviewMinute': reviewMinute,
        'minimumObservations': minimumObservations,
      };

  factory LifeSettings.fromJson(Map<String, dynamic> json) {
    return LifeSettings(
      calendarEnabled: json['calendarEnabled'] as bool? ?? false,
      remindersEnabled: json['remindersEnabled'] as bool? ?? false,
      reviewWeekday: (json['reviewWeekday'] as num?)?.toInt() ?? DateTime.sunday,
      reviewHour: (json['reviewHour'] as num?)?.toInt() ?? 18,
      reviewMinute: (json['reviewMinute'] as num?)?.toInt() ?? 0,
      minimumObservations: (json['minimumObservations'] as num?)?.toInt() ?? 5,
    );
  }
}

class SummaryCache {
  const SummaryCache({
    required this.dayKey,
    required this.fingerprint,
    required this.overview,
  });

  final String dayKey;
  final String fingerprint;
  final String overview;

  Map<String, dynamic> toJson() => {
        'dayKey': dayKey,
        'fingerprint': fingerprint,
        'overview': overview,
      };

  factory SummaryCache.fromJson(Map<String, dynamic> json) {
    return SummaryCache(
      dayKey: json['dayKey'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
      overview: json['overview'] as String? ?? '',
    );
  }
}

class LifeDocument {
  const LifeDocument({
    this.checkIns = const [],
    this.notes = const [],
    this.focusSessions = const [],
    this.activeFocus,
    this.settings = const LifeSettings(),
    this.dismissedExperiments = const [],
    this.cache,
  });

  final List<CheckIn> checkIns;
  final List<LifeNote> notes;
  final List<FocusRecord> focusSessions;
  final Map<String, dynamic>? activeFocus;
  final LifeSettings settings;
  final List<String> dismissedExperiments;
  final SummaryCache? cache;

  bool get isEmpty =>
      checkIns.isEmpty &&
      notes.isEmpty &&
      focusSessions.isEmpty &&
      activeFocus == null &&
      dismissedExperiments.isEmpty &&
      cache == null;

  LifeDocument copyWith({
    List<CheckIn>? checkIns,
    List<LifeNote>? notes,
    List<FocusRecord>? focusSessions,
    Map<String, dynamic>? activeFocus,
    bool clearActiveFocus = false,
    LifeSettings? settings,
    List<String>? dismissedExperiments,
    SummaryCache? cache,
    bool clearCache = false,
  }) {
    return LifeDocument(
      checkIns: checkIns ?? this.checkIns,
      notes: notes ?? this.notes,
      focusSessions: focusSessions ?? this.focusSessions,
      activeFocus: clearActiveFocus ? null : (activeFocus ?? this.activeFocus),
      settings: settings ?? this.settings,
      dismissedExperiments: dismissedExperiments ?? this.dismissedExperiments,
      cache: clearCache ? null : (cache ?? this.cache),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': 1,
        'checkIns': checkIns.map((e) => e.toJson()).toList(),
        'notes': notes.map((e) => e.toJson()).toList(),
        'focusSessions': focusSessions.map((e) => e.toJson()).toList(),
        'activeFocus': activeFocus,
        'settings': settings.toJson(),
        'dismissedExperiments': dismissedExperiments,
        'cache': cache?.toJson(),
      };

  factory LifeDocument.fromJson(Map<String, dynamic> json) {
    return LifeDocument(
      checkIns: ((json['checkIns'] as List?) ?? [])
          .map((e) => CheckIn.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      notes: ((json['notes'] as List?) ?? [])
          .map((e) => LifeNote.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      focusSessions: ((json['focusSessions'] as List?) ?? [])
          .map((e) => FocusRecord.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      activeFocus: (json['activeFocus'] as Map?)?.cast<String, dynamic>(),
      settings: json['settings'] is Map
          ? LifeSettings.fromJson((json['settings'] as Map).cast<String, dynamic>())
          : const LifeSettings(),
      dismissedExperiments: ((json['dismissedExperiments'] as List?) ?? [])
          .map((e) => e.toString())
          .toList(),
      cache: json['cache'] is Map
          ? SummaryCache.fromJson((json['cache'] as Map).cast<String, dynamic>())
          : null,
    );
  }

  factory LifeDocument.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const LifeDocument();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const LifeDocument();
      return LifeDocument.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      return const LifeDocument();
    }
  }
}
