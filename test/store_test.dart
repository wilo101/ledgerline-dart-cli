import 'dart:io';
import 'package:ledgerline/models/entry.dart';
import 'package:ledgerline/models/entry_filter.dart';
import 'package:ledgerline/models/recurring.dart';
import 'package:ledgerline/store.dart';
import 'package:test/test.dart';

void main() {
  late Store s;
  setUp(() {
    s = Store('x', persist: false)
      ..add('salary', 'Nov pay', 900, '2026-11-01')
      ..add('food', 'lunch with Sam', -12.5, '2026-11-02', ['social'])
      ..add('food', 'groceries', -60, '2026-11-09')
      ..add('rent', '', -400, '2026-10-01');
  });

  test('lists newest first', () => expect(s.list().map((e) => e.date).first, '2026-11-09'));

  test('filters by category, range, type, text, tag and amount', () {
    expect(s.query(const EntryFilter(category: 'food')).length, 2);
    expect(s.query(const EntryFilter(from: '2026-11-01')).length, 3);
    expect(s.query(const EntryFilter(to: '2026-10-31')).single.category, 'rent');
    expect(s.query(const EntryFilter(type: 'income')).single.category, 'salary');
    expect(s.query(const EntryFilter(type: 'expense')).length, 3);
    expect(s.query(const EntryFilter(text: 'SAM')).single.note, 'lunch with Sam');
    expect(s.query(const EntryFilter(tag: 'social')).length, 1);
    expect(s.query(const EntryFilter(minAmount: 50, maxAmount: 500)).length, 2);
  });

  test('update changes only the given fields', () {
    final id = s.list().last.id;
    final e = s.update(id, amount: -450)!;
    expect(e.amount, -450);
    expect(e.category, 'rent');
    expect(s.update(9999, note: 'x'), isNull);
  });

  test('remove', () {
    final id = s.list().first.id;
    expect(s.remove(id), isTrue);
    expect(s.remove(id), isFalse);
    expect(s.list().length, 3);
  });

  test('addAll skips duplicates unless told otherwise', () {
    final rows = [Entry(0, '2026-11-02', 'food', 'lunch with Sam', -12.5), Entry(0, '2026-11-20', 'fun', 'cinema', -9)];
    final r = s.addAll(rows);
    expect(r.added, 1);
    expect(r.duplicates, 1);
    expect(s.addAll(rows, skipDuplicates: false).added, 2);
  });

  test('categories are unique, sorted and include budget-only ones', () {
    s.setBudget('travel', 100);
    expect(s.categories, ['food', 'rent', 'salary', 'travel']);
  });

  test('persists everything to disk and loads it back', () {
    final f = '${Directory.systemTemp.createTempSync().path}/l.json';
    final a = Store(f)
      ..add('food', 'x', -5, '2026-11-01')
      ..setBudget('food', 100);
    a.addRecurring(category: 'rent', amount: -1, frequency: Frequency.monthly, startDate: '2026-11-01');
    final b = Store(f)..load();
    expect(b.list().length, 1);
    expect(b.budgets.single.monthlyLimit, 100);
    expect(b.recurring.length, 1);
    expect(b.add('y', '', 1).id, 2);
  });
}
