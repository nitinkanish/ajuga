import 'package:flutter/material.dart';

import '../../lifeos/models.dart';
import '../../lifeos/store.dart';
import '../../theme.dart';
import 'life_chrome.dart';

class CheckInsScreen extends StatefulWidget {
  const CheckInsScreen({super.key});

  @override
  State<CheckInsScreen> createState() => _CheckInsScreenState();
}

class _CheckInsScreenState extends State<CheckInsScreen> {
  final _store = LifeStore();
  final _note = TextEditingController();
  int _energy = 3;
  int _mood = 3;
  int _focus = 3;
  int _stress = 3;
  final _tags = <String>{};
  List<CheckIn> _history = [];

  static const _tagChoices = ['work', 'exercise', 'meal', 'social', 'sleep', 'commute'];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final document = await _store.load();
    if (!mounted) return;
    setState(() {
      _history = [...document.checkIns]..sort((a, b) => b.at.compareTo(a.at));
    });
  }

  Future<void> _save() async {
    final checkIn = CheckIn(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      at: DateTime.now(),
      energy: _energy,
      mood: _mood,
      focus: _focus,
      stress: _stress,
      note: _note.text.trim(),
      tags: _tags.toList(),
    );
    await _store.update((current) => current.copyWith(checkIns: [...current.checkIns, checkIn]));
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete(String id) async {
    await _store.update((current) {
      return current.copyWith(
        checkIns: current.checkIns.where((item) => item.id != id).toList(),
      );
    });
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    return LifePage(
      title: 'Check-in',
      subtitle: 'Optional, and stored only on this iPhone',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
        children: [
          Text(
            'Skip this whenever you want. Ratings are your own notes, not a health score.',
            style: TextStyle(color: colors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          _Scale(label: 'Energy', value: _energy, onChanged: (value) => setState(() => _energy = value)),
          _Scale(label: 'Mood', value: _mood, onChanged: (value) => setState(() => _mood = value)),
          _Scale(label: 'Focus', value: _focus, onChanged: (value) => setState(() => _focus = value)),
          _Scale(label: 'Stress', value: _stress, onChanged: (value) => setState(() => _stress = value)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _tagChoices)
                FilterChip(
                  label: Text(tag),
                  selected: _tags.contains(tag),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _tags.add(tag);
                      } else {
                        _tags.remove(tag);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note, optional'),
          ),
          const SizedBox(height: 16),
          LifeButton(label: 'Save check-in', onTap: _save),
          const SizedBox(height: 10),
          LifeButton(label: 'Skip', filled: false, onTap: () => Navigator.pop(context)),
          const SizedBox(height: 22),
          Text('Recent check-ins', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 8),
          if (_history.isEmpty)
            Text('None yet.', style: TextStyle(color: colors.muted))
          else
            for (final item in _history.take(20))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Energy ${item.energy} · Focus ${item.focus} · Stress ${item.stress}',
                  style: TextStyle(color: colors.ink),
                ),
                subtitle: Text(
                  '${item.at.month}/${item.at.day} ${item.at.hour.toString().padLeft(2, '0')}:${item.at.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(color: colors.muted),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                  onPressed: () => _delete(item.id),
                ),
              ),
        ],
      ),
    );
  }
}

class _Scale extends StatelessWidget {
  const _Scale({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(label, style: TextStyle(color: colors.ink, fontWeight: FontWeight.w600))),
          for (var level = 1; level <= 5; level++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onChanged(level),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: level <= value ? const Color(0xFF2457D6) : colors.line,
                  child: Text(
                    '$level',
                    style: TextStyle(color: level <= value ? Colors.white : colors.ink, fontSize: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
