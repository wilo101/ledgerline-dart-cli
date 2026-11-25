import 'package:ledgerline/report.dart';
import 'package:test/test.dart';

void main() {
  final rows = [Entry(1, '2026-11-01', 'salary', 'Nov, pay', 900), Entry(2, '2026-11-02', 'food', 'lunch', -12.5)];
  test('csv escapes commas', () => expect(toCsv(rows), contains('"Nov, pay"')));
  test('csv has a header with tags', () => expect(toCsv(rows).split('\n').first, 'id,date,category,amount,note,tags'));
  test('totals group by category', () => expect(totalsByCategory(rows), {'salary': 900.0, 'food': -12.5}));
  test('balance adds income and expenses', () => expect(balance(rows), 887.5));
  test('income and expenses are split', () {
    expect(income(rows), 900);
    expect(expenses(rows), 12.5);
  });
  test('table has header and rows', () => expect(toTable(rows).split('\n').length, 4));
}
