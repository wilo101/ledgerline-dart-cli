/// Dates are plain `YYYY-MM-DD` strings everywhere so they sort and compare as text.
String fmtDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDate(String s) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s.trim());
  if (m == null) throw FormatException('Not a YYYY-MM-DD date: $s');
  final d = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  if (d.month != int.parse(m[2]!)) throw FormatException('Not a real date: $s');
  return d;
}

bool isDate(String s) {
  try {
    parseDate(s);
    return true;
  } catch (_) {
    return false;
  }
}

/// `2026-11` for any date in November 2026.
String monthOf(String date) => date.substring(0, 7);

String monthNow([DateTime? now]) => monthOf(fmtDate(now ?? DateTime.now()));

int daysInMonth(int year, int month) => DateTime.utc(year, month + 1, 0).day;

/// Adds months and clamps the day (Jan 31 + 1 month = Feb 28 or 29).
DateTime addMonths(DateTime d, int months) {
  final total = d.year * 12 + (d.month - 1) + months;
  final y = total ~/ 12, m = total % 12 + 1;
  final day = d.day > daysInMonth(y, m) ? daysInMonth(y, m) : d.day;
  return DateTime.utc(y, m, day);
}
