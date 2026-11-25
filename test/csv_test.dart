import 'package:ledgerline/csv.dart';
import 'package:ledgerline/report.dart';
import 'package:test/test.dart';

void main() {
  test('parses quotes, escaped quotes and newlines in cells', () {
    final t = parseCsv('a,b\n"x, y","say ""hi"""\n"two\nlines",z\n');
    expect(t[1], ['x, y', 'say "hi"']);
    expect(t[2], ['two\nlines', 'z']);
  });

  test('handles CRLF and a missing final newline', () {
    expect(parseCsv('a,b\r\n1,2'), [['a', 'b'], ['1', '2']]);
  });

  test('import accepts columns in any order and any case', () {
    final r = importCsv('Amount,DATE,Category,Note\n-12.5,2026-11-02,food,lunch\n');
    expect(r.errors, isEmpty);
    expect(r.entries.single.amount, -12.5);
    expect(r.entries.single.category, 'food');
  });

  test('import reports bad rows by line number and keeps good ones', () {
    final r = importCsv('date,category,amount\n2026-11-01,food,-5\nnope,food,-5\n2026-11-03,,-5\n2026-11-04,food,abc\n2026-11-05,food,0\n');
    expect(r.entries.length, 1);
    expect(r.errors.map((e) => e.line), [3, 4, 5, 6]);
  });

  test('import needs the required columns', () {
    expect(() => importCsv('date,note\n2026-01-01,x'), throwsFormatException);
  });

  test('tags are split on semicolons', () {
    final r = importCsv('date,category,amount,tags\n2026-11-01,food,-5,"a; b"\n');
    expect(r.entries.single.tags, ['a', 'b']);
  });

  test('export then import round-trips', () {
    final rows = [Entry(1, '2026-11-01', 'salary', 'Nov, "pay"', 900, tags: ['work']), Entry(2, '2026-11-02', 'food', 'lunch', -12.5)];
    final back = importCsv(toCsv(rows)).entries;
    expect(back.length, 2);
    expect(back.first.note, 'Nov, "pay"');
    expect(back.first.tags, ['work']);
    expect(back.last.amount, -12.5);
  });
}
