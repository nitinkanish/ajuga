import 'dart:async';

import 'package:flutter/material.dart';

import '../../lifeos/focus.dart';
import '../../lifeos/models.dart';
import '../../lifeos/native.dart';
import '../../lifeos/reminders.dart';
import '../../lifeos/store.dart';
import 'life_chrome.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> with WidgetsBindingObserver {
  final _store = LifeStore();
  FocusSnapshot _snapshot = const FocusSnapshot();
  Timer? _ticker;
  bool _archiving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restore();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _tick();
  }

  Future<void> _restore() async {
    final document = await _store.load();
    final raw = document.activeFocus;
    final restored = raw == null ? const FocusSnapshot() : reconcileFocus(FocusSnapshot.fromJson(raw), DateTime.now());
    if (restored.phase == FocusPhase.finished && raw != null) {
      await _archive(restored);
      return;
    }
    if (!mounted) return;
    setState(() => _snapshot = restored);
  }

  Future<void> _persist(FocusSnapshot snapshot) async {
    await _store.update((current) => current.copyWith(activeFocus: snapshot.toJson()));
    final plan = focusCompletionPlan(
      running: snapshot.phase == FocusPhase.running,
      now: DateTime.now(),
      remainingSeconds: snapshot.remainingSeconds(DateTime.now()),
    );
    await LifeNative.applyPlan(plan, cancelId: focusReminderId);
  }

  Future<void> _act(String action) async {
    final now = DateTime.now();
    final next = transitionFocus(_snapshot, action, now);
    if (next.phase == FocusPhase.finished) {
      await _archive(next);
      return;
    }
    setState(() => _snapshot = next);
    await _persist(next);
  }

  Future<void> _archive(FocusSnapshot snapshot) async {
    if (_archiving) return;
    _archiving = true;
    final record = FocusRecord(
      id: snapshot.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      startedAt: snapshot.startedAt ?? DateTime.now(),
      endedAt: snapshot.endedAt ?? DateTime.now(),
      plannedSeconds: snapshot.plannedSeconds,
      elapsedSeconds: snapshot.elapsedSeconds,
      rating: snapshot.rating,
    );
    await _store.update((current) {
      return current.copyWith(
        focusSessions: [...current.focusSessions, record],
        clearActiveFocus: true,
      );
    });
    await LifeNative.cancel(focusReminderId);
    _archiving = false;
    if (!mounted) return;
    setState(() {
      _snapshot = FocusSnapshot(
        plannedSeconds: snapshot.plannedSeconds,
        breakSeconds: snapshot.breakSeconds,
      );
    });
  }

  Future<void> _rate(int rating) async {
    final document = await _store.load();
    if (document.focusSessions.isEmpty) return;
    final last = document.focusSessions.last;
    final rated = FocusRecord(
      id: last.id,
      startedAt: last.startedAt,
      endedAt: last.endedAt,
      plannedSeconds: last.plannedSeconds,
      elapsedSeconds: last.elapsedSeconds,
      rating: rating,
    );
    await _store.update((current) {
      final sessions = [...current.focusSessions];
      if (sessions.isNotEmpty) sessions[sessions.length - 1] = rated;
      return current.copyWith(focusSessions: sessions);
    });
  }

  void _tick() {
    final now = DateTime.now();
    final reconciled = reconcileFocus(_snapshot, now);
    if (reconciled.phase == FocusPhase.finished && _snapshot.phase == FocusPhase.running) {
      _archive(reconciled);
      return;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    final now = DateTime.now();
    final live = reconcileFocus(_snapshot, now);
    final remaining = live.remainingSeconds(now);
    final minutes = (remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final running = live.phase == FocusPhase.running;
    final paused = live.phase == FocusPhase.paused;
    return LifePage(
      title: 'Focus',
      subtitle: 'A timer, not a measure of work',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Text(
            'The timer only tracks the session you start. It does not watch other apps.',
            style: TextStyle(color: colors.muted, height: 1.4),
          ),
          const SizedBox(height: 24),
          Text(
            '$minutes:$seconds',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.ink, fontSize: 64, fontWeight: FontWeight.w600, letterSpacing: -1),
          ),
          const SizedBox(height: 8),
          Text(
            live.phase.name,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: 20),
          if (!running && !paused) ...[
            Text('Session', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final minutes in [15, 25, 45])
                  ChoiceChip(
                    label: Text('$minutes min'),
                    selected: live.plannedSeconds == minutes * 60,
                    onSelected: (_) async {
                      final next = configureFocus(_snapshot, plannedSeconds: minutes * 60);
                      setState(() => _snapshot = next);
                      await _persist(next);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Break', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final minutes in [5, 10])
                  ChoiceChip(
                    label: Text('$minutes min'),
                    selected: live.breakSeconds == minutes * 60,
                    onSelected: (_) async {
                      final next = configureFocus(_snapshot, breakSeconds: minutes * 60);
                      setState(() => _snapshot = next);
                      await _persist(next);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            LifeButton(label: 'Start', onTap: () => _act('start')),
          ],
          if (running) ...[
            LifeButton(label: 'Pause', onTap: () => _act('pause')),
            const SizedBox(height: 10),
            LifeButton(label: 'Finish', filled: false, onTap: () => _act('finish')),
          ],
          if (paused) ...[
            LifeButton(label: 'Resume', onTap: () => _act('resume')),
            const SizedBox(height: 10),
            LifeButton(label: 'Finish', filled: false, onTap: () => _act('finish')),
          ],
          const SizedBox(height: 18),
          Text('Optional rating after a session', style: TextStyle(color: colors.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (var level = 1; level <= 5; level++)
                ActionChip(label: Text('$level'), onPressed: () => _rate(level)),
            ],
          ),
        ],
      ),
    );
  }
}
