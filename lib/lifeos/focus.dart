enum FocusPhase { idle, running, paused, finished }

class FocusSnapshot {
  const FocusSnapshot({
    this.id,
    this.phase = FocusPhase.idle,
    this.plannedSeconds = 25 * 60,
    this.breakSeconds = 5 * 60,
    this.elapsedSeconds = 0,
    this.runningSince,
    this.startedAt,
    this.endedAt,
    this.rating,
  });

  final String? id;
  final FocusPhase phase;
  final int plannedSeconds;
  final int breakSeconds;
  final int elapsedSeconds;
  final DateTime? runningSince;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int? rating;

  int displayedSeconds(DateTime now) {
    var elapsed = elapsedSeconds;
    if (phase == FocusPhase.running && runningSince != null) {
      elapsed += now.difference(runningSince!).inSeconds;
    }
    if (elapsed < 0) return 0;
    if (elapsed > plannedSeconds) return plannedSeconds;
    return elapsed;
  }

  int remainingSeconds(DateTime now) {
    final left = plannedSeconds - displayedSeconds(now);
    return left < 0 ? 0 : left;
  }

  FocusSnapshot copy({
    String? id,
    FocusPhase? phase,
    int? plannedSeconds,
    int? breakSeconds,
    int? elapsedSeconds,
    DateTime? runningSince,
    bool clearRunningSince = false,
    DateTime? startedAt,
    DateTime? endedAt,
    int? rating,
  }) {
    return FocusSnapshot(
      id: id ?? this.id,
      phase: phase ?? this.phase,
      plannedSeconds: plannedSeconds ?? this.plannedSeconds,
      breakSeconds: breakSeconds ?? this.breakSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      runningSince: clearRunningSince ? null : (runningSince ?? this.runningSince),
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      rating: rating ?? this.rating,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'phase': phase.name,
        'plannedSeconds': plannedSeconds,
        'breakSeconds': breakSeconds,
        'elapsedSeconds': elapsedSeconds,
        'runningSince': runningSince?.millisecondsSinceEpoch,
        'startedAt': startedAt?.millisecondsSinceEpoch,
        'endedAt': endedAt?.millisecondsSinceEpoch,
        'rating': rating,
      };

  factory FocusSnapshot.fromJson(Map<String, dynamic> json) {
    return FocusSnapshot(
      id: json['id'] as String?,
      phase: FocusPhase.values.firstWhere(
        (phase) => phase.name == json['phase'],
        orElse: () => FocusPhase.idle,
      ),
      plannedSeconds: (json['plannedSeconds'] as num?)?.toInt() ?? 25 * 60,
      breakSeconds: (json['breakSeconds'] as num?)?.toInt() ?? 5 * 60,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      runningSince: json['runningSince'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((json['runningSince'] as num).toInt()),
      startedAt: json['startedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((json['startedAt'] as num).toInt()),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch((json['endedAt'] as num).toInt()),
      rating: (json['rating'] as num?)?.toInt(),
    );
  }
}

FocusSnapshot reconcileFocus(FocusSnapshot snapshot, DateTime now) {
  if (snapshot.phase != FocusPhase.running || snapshot.runningSince == null) {
    return snapshot;
  }
  if (snapshot.displayedSeconds(now) < snapshot.plannedSeconds) return snapshot;
  final ended = snapshot.runningSince!.add(
    Duration(seconds: snapshot.plannedSeconds - snapshot.elapsedSeconds),
  );
  return snapshot.copy(
    phase: FocusPhase.finished,
    elapsedSeconds: snapshot.plannedSeconds,
    clearRunningSince: true,
    endedAt: ended,
  );
}

FocusSnapshot transitionFocus(FocusSnapshot snapshot, String action, DateTime now) {
  final current = reconcileFocus(snapshot, now);
  switch (action) {
    case 'start':
      if (current.phase == FocusPhase.running || current.phase == FocusPhase.paused) {
        return current;
      }
      return FocusSnapshot(
        id: now.microsecondsSinceEpoch.toString(),
        phase: FocusPhase.running,
        plannedSeconds: current.plannedSeconds,
        breakSeconds: current.breakSeconds,
        elapsedSeconds: 0,
        runningSince: now,
        startedAt: now,
      );
    case 'pause':
      if (current.phase != FocusPhase.running) return current;
      return current.copy(
        phase: FocusPhase.paused,
        elapsedSeconds: current.displayedSeconds(now),
        clearRunningSince: true,
      );
    case 'resume':
      if (current.phase != FocusPhase.paused) return current;
      return current.copy(phase: FocusPhase.running, runningSince: now);
    case 'finish':
      if (current.phase != FocusPhase.running && current.phase != FocusPhase.paused) {
        return current;
      }
      return current.copy(
        phase: FocusPhase.finished,
        elapsedSeconds: current.displayedSeconds(now),
        clearRunningSince: true,
        endedAt: now,
      );
    case 'rate':
      return current;
    default:
      return current;
  }
}

FocusSnapshot configureFocus(FocusSnapshot snapshot, {int? plannedSeconds, int? breakSeconds}) {
  if (snapshot.phase == FocusPhase.running || snapshot.phase == FocusPhase.paused) {
    return snapshot;
  }
  return snapshot.copy(
    phase: FocusPhase.idle,
    plannedSeconds: plannedSeconds ?? snapshot.plannedSeconds,
    breakSeconds: breakSeconds ?? snapshot.breakSeconds,
    elapsedSeconds: 0,
    clearRunningSince: true,
  );
}
