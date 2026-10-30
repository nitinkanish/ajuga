/// Local-day math that does not depend on the host time zone.
/// [offsetAt] returns the zone offset for a UTC instant, so tests can model
/// India (fixed +5:30) and a US daylight-saving year.
library;

class ZonedClock {
  const ZonedClock(this.offsetAt);

  final Duration Function(DateTime utc) offsetAt;

  DateTime toLocal(DateTime instant) {
    final utc = instant.toUtc();
    return utc.add(offsetAt(utc));
  }

  String dayKey(DateTime instant) {
    final local = toLocal(instant);
    return formatDay(local.year, local.month, local.day);
  }

  /// UTC instant whose zoned wall time is midnight on [year]/[month]/[day].
  DateTime utcAtLocalMidnight(int year, int month, int day) {
    final nominal = DateTime.utc(year, month, day);
    for (var minutes = -20 * 60; minutes <= 20 * 60; minutes++) {
      final guess = nominal.add(Duration(minutes: minutes));
      final local = guess.add(offsetAt(guess));
      if (local.year == year &&
          local.month == month &&
          local.day == day &&
          local.hour == 0 &&
          local.minute == 0) {
        return guess;
      }
    }
    throw StateError('No midnight mapping for $year-$month-$day');
  }

  Duration lengthOfLocalDay(int year, int month, int day) {
    final start = utcAtLocalMidnight(year, month, day);
    final next = DateTime.utc(year, month, day).add(const Duration(days: 1));
    final end = utcAtLocalMidnight(next.year, next.month, next.day);
    return end.difference(start);
  }
}

String formatDay(int year, int month, int day) {
  final y = year.toString().padLeft(4, '0');
  final m = month.toString().padLeft(2, '0');
  final d = day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Fixed India offset. India does not observe daylight saving.
Duration indiaOffset(DateTime utc) => const Duration(hours: 5, minutes: 30);

/// US Eastern civil time for 2026. Spring forward 8 Mar 07:00 UTC,
/// fall back 1 Nov 06:00 UTC.
Duration usEastern2026(DateTime utc) {
  final instant = utc.toUtc();
  final spring = DateTime.utc(2026, 3, 8, 7);
  final fall = DateTime.utc(2026, 11, 1, 6);
  if (!instant.isBefore(spring) && instant.isBefore(fall)) {
    return const Duration(hours: -4);
  }
  return const Duration(hours: -5);
}

DateTime startOfLocalDay(DateTime instant) {
  return DateTime(instant.year, instant.month, instant.day);
}

DateTime nextLocalDay(DateTime day) {
  final start = startOfLocalDay(day);
  return DateTime(start.year, start.month, start.day + 1);
}

/// Monday-start week containing [day] in that DateTime's calendar.
DateTime weekStartMonday(DateTime day) {
  final start = startOfLocalDay(day);
  return start.subtract(Duration(days: start.weekday - DateTime.monday));
}

bool sameLocalDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String greetingForHour(int hour) {
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}
