import 'package:flutter/material.dart';

import '../../lifeos/models.dart';
import '../../lifeos/native.dart';
import '../../lifeos/reminders.dart';
import '../../lifeos/store.dart';
import '../../motion/activity_bridge.dart';
import '../../theme.dart';
import 'life_chrome.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _store = LifeStore();
  LifeDocument _document = const LifeDocument();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final document = await _store.load();
    if (!mounted) return;
    setState(() {
      _document = document;
      _loading = false;
    });
  }

  Future<void> _save(LifeSettings settings) async {
    await _store.update((current) => current.copyWith(settings: settings));
    final plan = weeklyReviewPlan(
      now: DateTime.now(),
      enabled: settings.remindersEnabled,
      weekday: settings.reviewWeekday,
      hour: settings.reviewHour,
      minute: settings.reviewMinute,
    );
    await LifeNative.applyPlan(plan, cancelId: weeklyReminderId);
    await _load();
  }

  Future<void> _calendar(bool enabled) async {
    if (enabled) {
      final result = await LifeNative.requestCalendar();
      final status = result['status'] as String? ?? '';
      if (status != 'authorized') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calendar stays off until access is allowed.')),
        );
        return;
      }
    }
    await _save(_document.settings.copyWith(calendarEnabled: enabled));
  }

  Future<void> _reminders(bool enabled) async {
    if (enabled) {
      final granted = await LifeNative.requestNotifications();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminders stay off until notifications are allowed.')),
        );
        return;
      }
    }
    await _save(_document.settings.copyWith(remindersEnabled: enabled));
  }

  Future<void> _deleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete LifeOS data?'),
          content: const Text(
            'This removes check-ins, notes, focus sessions, insights, and cached summaries from Ajuga. It does not delete Apple Health, Calendar, or Motion data kept by iOS.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _store.deleteAll();
    await LifeNative.cancel(weeklyReminderId);
    await LifeNative.cancel(focusReminderId);
    await _load();
  }

  Future<void> _health() async {
    try {
      await ActivityBridge.requestHealthAuthorization();
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Health access was requested. Denied access is not treated as zero activity.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    final settings = _document.settings;
    return LifePage(
      title: 'Privacy',
      subtitle: 'On this iPhone',
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Text(
                  'Check-ins, notes, focus sessions, and derived summaries stay in Ajuga. Nothing in LifeOS is sent to an analytics service or an external AI.',
                  style: TextStyle(color: colors.ink, height: 1.4),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Calendar events'),
                  subtitle: const Text('Optional. Titles stay on this phone and do not prove attendance.'),
                  value: settings.calendarEnabled,
                  onChanged: _calendar,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Weekly reminder'),
                  subtitle: Text('Sundays at ${settings.reviewHour.toString().padLeft(2, '0')}:00, unless you turn this off.'),
                  value: settings.remindersEnabled,
                  onChanged: _reminders,
                ),
                const SizedBox(height: 8),
                Text('Minimum check-ins before a pattern', style: TextStyle(color: colors.ink, fontWeight: FontWeight.w600)),
                Slider(
                  value: settings.minimumObservations.toDouble(),
                  min: 4,
                  max: 12,
                  divisions: 8,
                  label: '${settings.minimumObservations}',
                  onChanged: (value) {
                    setState(() {
                      _document = _document.copyWith(
                        settings: settings.copyWith(minimumObservations: value.round()),
                      );
                    });
                  },
                  onChangeEnd: (value) {
                    _save(settings.copyWith(minimumObservations: value.round()));
                  },
                ),
                const SizedBox(height: 8),
                LifeButton(label: 'Allow Apple Health', filled: false, onTap: _health),
                const SizedBox(height: 10),
                LifeButton(label: 'Delete LifeOS data', onTap: _deleteAll),
                const SizedBox(height: 14),
                Text(
                  'Deleting Ajuga does not remove samples that Apple Health or Calendar already store.',
                  style: const TextStyle(color: AppColors.muted, height: 1.4, fontSize: 12),
                ),
              ],
            ),
    );
  }
}
