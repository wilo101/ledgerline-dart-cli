import '../dates.dart';

enum Frequency { weekly, monthly, yearly }

/// A rule that creates an entry on a schedule (rent, salary, subscriptions).
class Recurring {
  Recurring({
    required this.id,
    required this.category,
    required this.amount,
    required this.frequency,
    required this.startDate,
    this.note = '',
    this.endDate,
    String? lastRun,
  }) : lastRun = lastRun;

  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(
        id: j['id'] as int,
        category: '${j['category']}',
        amount: (j['amount'] as num).toDouble(),
        frequency: Frequency.values.firstWhere((f) => f.name == j['frequency']),
        startDate: '${j['startDate']}',
        note: '${j['note'] ?? ''}',
        endDate: j['endDate'] as String?,
        lastRun: j['lastRun'] as String?,
      );

  final int id;
  final String category, note, startDate;
  final double amount;
  final Frequency frequency;
  final String? endDate;

  /// Date of the most recent entry this rule created.
  String? lastRun;

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'amount': amount,
        'frequency': frequency.name,
        'startDate': startDate,
        'note': note,
        'endDate': endDate,
        'lastRun': lastRun,
      };

  /// Every due date from the start up to and including [until], skipping those already created.
  /// Monthly rules keep the original day of month (a rule starting on the 31st lands on the last day of short months).
  List<String> dueDates(String until) {
    final start = parseDate(startDate);
    final stop = parseDate(endDate != null && endDate!.compareTo(until) < 0 ? endDate! : until);
    final out = <String>[];
    var n = 0;
    while (true) {
      final d = switch (frequency) {
        Frequency.weekly => start.add(Duration(days: 7 * n)),
        Frequency.monthly => addMonths(start, n),
        Frequency.yearly => addMonths(start, 12 * n),
      };
      if (d.isAfter(stop)) break;
      final s = fmtDate(d);
      if (lastRun == null || s.compareTo(lastRun!) > 0) out.add(s);
      n++;
      if (n > 5000) break;
    }
    return out;
  }
}
