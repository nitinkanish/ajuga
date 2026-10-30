class NotificationPlan {
  const NotificationPlan({
    required this.id,
    required this.fireAt,
    required this.title,
    required this.body,
    required this.repeatsWeekly,
  });

  final String id;
  final DateTime fireAt;
  final String title;
  final String body;
  final bool repeatsWeekly;
}

const weeklyReminderId = 'lifeos.weekly';
const focusReminderId = 'lifeos.focus';

/// Next local wall-clock occurrence of [weekday] at [hour]:[minute] after [now].
DateTime nextWeeklyFire({
  required DateTime now,
  required int weekday,
  required int hour,
  required int minute,
}) {
  for (var i = 0; i < 8; i++) {
    final day = DateTime(now.year, now.month, now.day + i, hour, minute);
    if (day.weekday == weekday && day.isAfter(now)) return day;
  }
  return DateTime(now.year, now.month, now.day + 7, hour, minute);
}

NotificationPlan? weeklyReviewPlan({
  required DateTime now,
  required bool enabled,
  required int weekday,
  required int hour,
  required int minute,
}) {
  if (!enabled) return null;
  return NotificationPlan(
    id: weeklyReminderId,
    fireAt: nextWeeklyFire(now: now, weekday: weekday, hour: hour, minute: minute),
    title: 'Weekly life review',
    body: 'Your on-device review is ready. Nothing is sent off this iPhone.',
    repeatsWeekly: true,
  );
}

NotificationPlan? focusCompletionPlan({
  required bool running,
  required DateTime now,
  required int remainingSeconds,
}) {
  if (!running || remainingSeconds <= 0) return null;
  return NotificationPlan(
    id: focusReminderId,
    fireAt: now.add(Duration(seconds: remainingSeconds)),
    title: 'Focus session finished',
    body: 'The timer is done. Duration is not a measure of how productive the time was.',
    repeatsWeekly: false,
  );
}
