class Entry {
  Entry(this.id, this.date, this.category, this.note, this.amount);
  factory Entry.fromJson(Map<String, dynamic> j) =>
      Entry(j['id'] as int, '${j['date']}', '${j['category']}', '${j['note']}', (j['amount'] as num).toDouble());
  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'category': category, 'note': note, 'amount': amount};
  final int id;
  final String date, category, note;

  /// Positive = income, negative = expense.
  final double amount;
}

String toTable(List<Entry> rows) {
  final b = StringBuffer()..writeln('ID    DATE        CATEGORY    AMOUNT   NOTE');
  for (final r in rows) {
    b.writeln('${r.id.toString().padRight(5)} ${r.date} ${r.category.padRight(11)} ${r.amount.toStringAsFixed(2).padLeft(8)}  ${r.note}');
  }
  return b.toString();
}

String toCsv(List<Entry> rows) {
  String esc(String v) => v.contains(',') || v.contains('"') ? '"${v.replaceAll('"', '""')}"' : v;
  final b = StringBuffer()..writeln('id,date,category,amount,note');
  for (final r in rows) {
    b.writeln('${r.id},${r.date},${esc(r.category)},${r.amount.toStringAsFixed(2)},${esc(r.note)}');
  }
  return b.toString();
}

Map<String, double> totalsByCategory(List<Entry> rows) {
  final m = <String, double>{};
  for (final r in rows) {
    m[r.category] = (m[r.category] ?? 0) + r.amount;
  }
  return m;
}

double balance(List<Entry> rows) => rows.fold(0.0, (a, r) => a + r.amount);
