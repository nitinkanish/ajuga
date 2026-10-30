import 'package:flutter/material.dart';

import '../../lifeos/dashboard.dart';
import '../../lifeos/load.dart';
import '../../lifeos/models.dart';
import '../../lifeos/store.dart';
import 'life_chrome.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final _store = LifeStore();
  final _note = TextEditingController();
  List<TimelineEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final document = await _store.load();
    final model = await LifeLoader.loadDashboard(document);
    if (!mounted) return;
    setState(() {
      _entries = model.timeline;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    await _store.update((current) {
      return current.copyWith(
        notes: [
          ...current.notes,
          LifeNote(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            at: DateTime.now(),
            text: text,
          ),
        ],
      );
    });
    _note.clear();
    await _load();
  }

  Future<void> _delete(String id) async {
    await _store.update((current) {
      return current.copyWith(notes: current.notes.where((note) => note.id != id).toList());
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    return LifePage(
      title: 'Today',
      subtitle: 'Signals you already allowed',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Text(
                  'Calendar events and motion labels are clues, not a record of where you were or what you did.',
                  style: TextStyle(color: colors.muted, height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(labelText: 'Add a private note'),
                ),
                const SizedBox(height: 10),
                LifeButton(label: 'Add note', onTap: _add),
                const SizedBox(height: 18),
                if (_entries.isEmpty)
                  Text(
                    'No signals recorded yet. An empty timeline is not an empty day.',
                    style: TextStyle(color: colors.muted, height: 1.4),
                  )
                else
                  for (final entry in _entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LifeCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_clock(entry.start), style: TextStyle(color: colors.muted, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(entry.title, style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(entry.detail, style: TextStyle(color: colors.muted, height: 1.35)),
                            if (entry.editableId != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _delete(entry.editableId!),
                                  child: const Text('Delete note'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
    );
  }

  String _clock(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
