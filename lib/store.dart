import 'dart:convert';
import 'dart:io';
import 'report.dart';

/// JSON-file storage so the service runs with no database.
class Store {
  Store(this.path);
  final String path;
  final List<Entry> _entries = [];
  int _next = 1;

  void load() {
    final f = File(path);
    if (!f.existsSync()) return;
    final data = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    _entries
      ..clear()
      ..addAll([for (final j in data['entries'] as List) Entry.fromJson(j as Map<String, dynamic>)]);
    _next = data['next'] as int;
  }

  void _save() => File(path).writeAsStringSync(jsonEncode({'next': _next, 'entries': [for (final e in _entries) e.toJson()]}));

  List<Entry> list({String? category}) =>
      _entries.where((e) => category == null || e.category == category).toList()..sort((a, b) => b.date.compareTo(a.date));

  Entry add(String category, String note, double amount, [String? date]) {
    final e = Entry(_next++, date ?? DateTime.now().toIso8601String().substring(0, 10), category, note, amount);
    _entries.add(e);
    _save();
    return e;
  }

  bool remove(int id) {
    final n = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (_entries.length == n) return false;
    _save();
    return true;
  }
}
