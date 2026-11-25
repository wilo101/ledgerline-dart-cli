import 'package:ledgerline/models/budget.dart';
import 'package:ledgerline/report.dart';
import 'package:test/test.dart';

void main() {
  final rows = [
    Entry(1, '2026-11-02', 'food', '', -120),
    Entry(2, '2026-11-09', 'food', '', -90),
    Entry(3, '2026-10-30', 'food', '', -500),
    Entry(4, '2026-11-03', 'salary', '', 1000),
    Entry(5, '2026-11-04', 'fun', '', -40),
  ];

  test('counts only expenses in the given month and category', () {
    final s = budgetStatuses([Budget('food', 300)], rows, '2026-11').single;
    expect(s.spent, 210);
    expect(s.remaining, 90);
    expect(s.ratio, closeTo(0.7, 1e-9));
  });

  test('levels: ok, warning at 80 percent, over at 100 percent', () {
    BudgetLevel at(double limit) => budgetStatuses([Budget('food', limit)], rows, '2026-11').single.level;
    expect(at(1000), BudgetLevel.ok);
    expect(at(250), BudgetLevel.warning);
    expect(at(210), BudgetLevel.over);
    expect(at(100), BudgetLevel.over);
  });

  test('income never counts toward a budget', () {
    expect(budgetStatuses([Budget('salary', 500)], rows, '2026-11').single.spent, 0);
  });

  test('json rounds and names the level', () {
    final j = budgetStatuses([Budget('food', 300)], rows, '2026-11').single.toJson();
    expect(j['percent'], 70.0);
    expect(j['level'], 'ok');
  });

  test('breakdown is sorted with shares that add up', () {
    final b = spendingBreakdown(rows, '2026-11');
    expect(b.first['category'], 'food');
    expect(b.map((e) => e['share'] as num).reduce((a, c) => a + c), closeTo(100, 0.2));
  });

  test('monthly totals are oldest first', () {
    final m = monthlyTotals(rows);
    expect(m.map((e) => e['month']), ['2026-10', '2026-11']);
    expect(m.last['income'], 1000);
    expect(m.last['expenses'], 250);
    expect(m.last['net'], 750);
  });

  test('text report flags overspent budgets', () {
    final text = monthlyReport(rows, [Budget('food', 100)], '2026-11');
    expect(text, contains('Report for 2026-11'));
    expect(text, contains('OVER'));
  });
}
