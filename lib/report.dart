import 'dates.dart';
import 'models/budget.dart';
import 'models/entry.dart';

export 'models/entry.dart';

String toTable(List<Entry> rows) {
  final b = StringBuffer()..writeln('ID    DATE        CATEGORY    AMOUNT   NOTE');
  for (final r in rows) {
    b.writeln('${r.id.toString().padRight(5)} ${r.date} ${r.category.padRight(11)} ${r.amount.toStringAsFixed(2).padLeft(8)}  ${r.note}');
  }
  return b.toString();
}

String _esc(String v) => v.contains(',') || v.contains('"') || v.contains('\n') ? '"${v.replaceAll('"', '""')}"' : v;

String toCsv(List<Entry> rows) {
  final b = StringBuffer()..writeln('id,date,category,amount,note,tags');
  for (final r in rows) {
    b.writeln('${r.id},${r.date},${_esc(r.category)},${r.amount.toStringAsFixed(2)},${_esc(r.note)},${_esc(r.tags.join(';'))}');
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

double income(List<Entry> rows) => rows.where((e) => e.amount > 0).fold(0.0, (a, e) => a + e.amount);

/// Expenses as a positive number.
double expenses(List<Entry> rows) => -rows.where((e) => e.amount < 0).fold(0.0, (a, e) => a + e.amount);

/// Income, expenses and net for each month, oldest first.
List<Map<String, dynamic>> monthlyTotals(List<Entry> rows) {
  final m = <String, List<double>>{};
  for (final e in rows) {
    final t = m.putIfAbsent(monthOf(e.date), () => [0, 0]);
    e.amount > 0 ? t[0] += e.amount : t[1] -= e.amount;
  }
  final keys = m.keys.toList()..sort();
  return [
    for (final k in keys)
      {
        'month': k,
        'income': double.parse(m[k]![0].toStringAsFixed(2)),
        'expenses': double.parse(m[k]![1].toStringAsFixed(2)),
        'net': double.parse((m[k]![0] - m[k]![1]).toStringAsFixed(2)),
      }
  ];
}

/// Spending per category in a month, biggest first, with each share of the month's total.
List<Map<String, dynamic>> spendingBreakdown(List<Entry> rows, String month) {
  final spent = <String, double>{};
  for (final e in rows.where((e) => e.amount < 0 && monthOf(e.date) == month)) {
    spent[e.category] = (spent[e.category] ?? 0) - e.amount;
  }
  final total = spent.values.fold(0.0, (a, v) => a + v);
  final list = spent.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in list)
      {
        'category': e.key,
        'spent': double.parse(e.value.toStringAsFixed(2)),
        'share': total == 0 ? 0 : double.parse((e.value / total * 100).toStringAsFixed(1)),
      }
  ];
}

List<BudgetStatus> budgetStatuses(List<Budget> budgets, List<Entry> rows, String month) => [
      for (final b in budgets)
        BudgetStatus(
          b,
          month,
          -rows.where((e) => e.category == b.category && e.amount < 0 && monthOf(e.date) == month).fold(0.0, (a, e) => a + e.amount),
        )
    ];

/// A plain-text monthly report for the terminal.
String monthlyReport(List<Entry> rows, List<Budget> budgets, String month) {
  final inMonth = rows.where((e) => monthOf(e.date) == month).toList();
  final b = StringBuffer()
    ..writeln('Report for $month')
    ..writeln('Income    ${income(inMonth).toStringAsFixed(2).padLeft(10)}')
    ..writeln('Expenses  ${expenses(inMonth).toStringAsFixed(2).padLeft(10)}')
    ..writeln('Net       ${balance(inMonth).toStringAsFixed(2).padLeft(10)}')
    ..writeln('\nSpending by category');
  for (final s in spendingBreakdown(rows, month)) {
    b.writeln('  ${('${s['category']}').padRight(12)} ${(s['spent'] as double).toStringAsFixed(2).padLeft(9)}  ${s['share']}%');
  }
  final statuses = budgetStatuses(budgets, rows, month);
  if (statuses.isNotEmpty) {
    b.writeln('\nBudgets');
    for (final s in statuses) {
      final flag = switch (s.level) { BudgetLevel.over => 'OVER', BudgetLevel.warning => 'close', BudgetLevel.ok => 'ok' };
      b.writeln('  ${s.budget.category.padRight(12)} ${s.spent.toStringAsFixed(2).padLeft(9)} / ${s.budget.monthlyLimit.toStringAsFixed(2)}  $flag');
    }
  }
  return b.toString();
}
