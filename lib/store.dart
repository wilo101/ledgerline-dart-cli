import 'dart:convert';
import 'dart:io';
import 'dates.dart';
import 'models/budget.dart';
import 'models/entry.dart';
import 'models/entry_filter.dart';
import 'models/recurring.dart';

/// JSON-file storage so the service runs with no database.
/// Pass `persist: false` for an in-memory store (used by the tests).
class Store {
  Store(this.path, {this.persist = true});
  final String path;
  final bool persist;

  final List<Entry> _entries = [];
  final Map<String, Budget> _budgets = {};
  final List<Recurring> _recurring = [];
  int _next = 1;
  int _nextRecurring = 1;

  void load() {
    final f = File(path);
    if (!persist || !f.existsSync()) return;
    final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    _entries
      ..clear()
      ..addAll([for (final j in data['entries'] as List) Entry.fromJson(j as Map<String, dynamic>)]);
    _next = data['next'] as int;
    for (final j in (data['budgets'] ?? const []) as List) {
      final b = Budget.fromJson(j as Map<String, dynamic>);
      _budgets[b.category] = b;
    }
    _recurring
      ..clear()
      ..addAll([for (final j in (data['recurring'] ?? const []) as List) Recurring.fromJson(j as Map<String, dynamic>)]);
    _nextRecurring = (data['nextRecurring'] ?? 1) as int;
  }

  void _save() {
    if (!persist) return;
    File(path).writeAsStringSync(jsonEncode({
      'next': _next,
      'nextRecurring': _nextRecurring,
      'entries': [for (final e in _entries) e.toJson()],
      'budgets': [for (final b in _budgets.values) b.toJson()],
      'recurring': [for (final r in _recurring) r.toJson()],
    }));
  }

  // ---- entries
  List<Entry> list({String? category}) => query(EntryFilter(category: category));

  /// Newest first, then highest id first.
  List<Entry> query(EntryFilter f) => _entries.where(f.matches).toList()
    ..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.id.compareTo(a.id);
    });

  Entry? get(int id) {
    for (final e in _entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  Entry add(String category, String note, double amount, [String? date, List<String> tags = const [], int? recurringId]) {
    final e = Entry(_next++, date ?? fmtDate(DateTime.now()), category.trim(), note, amount, recurringId: recurringId, tags: tags);
    _entries.add(e);
    _save();
    return e;
  }

  Entry? update(int id, {String? date, String? category, String? note, double? amount, List<String>? tags}) {
    final i = _entries.indexWhere((e) => e.id == id);
    if (i < 0) return null;
    _entries[i] = _entries[i].copyWith(date: date, category: category, note: note, amount: amount, tags: tags);
    _save();
    return _entries[i];
  }

  bool remove(int id) {
    final n = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length == n) return false;
    _save();
    return true;
  }

  /// Adds many entries with one save. Skips rows that match an existing entry on date, category, amount and note.
  ({int added, int duplicates}) addAll(Iterable<Entry> rows, {bool skipDuplicates = true}) {
    var added = 0, dup = 0;
    final seen = {for (final e in _entries) _key(e)};
    for (final r in rows) {
      if (skipDuplicates && !seen.add(_key(r))) {
        dup++;
        continue;
      }
      _entries.add(Entry(_next++, r.date, r.category, r.note, r.amount, tags: r.tags));
      added++;
    }
    _save();
    return (added: added, duplicates: dup);
  }

  static String _key(Entry e) => '${e.date}|${e.category}|${e.amount}|${e.note}';

  List<String> get categories => ({for (final e in _entries) e.category, ..._budgets.keys}.toList()..sort());

  // ---- budgets
  List<Budget> get budgets => _budgets.values.toList()..sort((a, b) => a.category.compareTo(b.category));

  Budget setBudget(String category, double limit) {
    final b = Budget(category, limit);
    _budgets[category] = b;
    _save();
    return b;
  }

  bool removeBudget(String category) {
    final had = _budgets.remove(category) != null;
    if (had) _save();
    return had;
  }

  // ---- recurring
  List<Recurring> get recurring => List.unmodifiable(_recurring);

  Recurring addRecurring({
    required String category,
    required double amount,
    required Frequency frequency,
    required String startDate,
    String note = '',
    String? endDate,
  }) {
    final r = Recurring(
        id: _nextRecurring++, category: category, amount: amount, frequency: frequency, startDate: startDate, note: note, endDate: endDate);
    _recurring.add(r);
    _save();
    return r;
  }

  bool removeRecurring(int id) {
    final n = _recurring.length;
    _recurring.removeWhere((r) => r.id == id);
    if (_recurring.length == n) return false;
    _save();
    return true;
  }

  /// Creates every entry that is due up to [today] and remembers where each rule got to,
  /// so running it twice never doubles anything.
  List<Entry> runRecurring([String? today]) {
    final until = today ?? fmtDate(DateTime.now());
    final created = <Entry>[];
    for (final r in _recurring) {
      for (final d in r.dueDates(until)) {
        _entries.add(Entry(_next++, d, r.category, r.note, r.amount, recurringId: r.id));
        created.add(_entries.last);
        r.lastRun = d;
      }
    }
    if (created.isNotEmpty) _save();
    return created;
  }
}
