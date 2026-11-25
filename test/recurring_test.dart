import 'package:ledgerline/models/recurring.dart';
import 'package:ledgerline/store.dart';
import 'package:test/test.dart';

Recurring rule(Frequency f, String start, {String? end, String? last}) =>
    Recurring(id: 1, category: 'rent', amount: -500, frequency: f, startDate: start, endDate: end, lastRun: last);

void main() {
  group('due dates', () {
    test('monthly includes the start and each month up to today', () {
      expect(rule(Frequency.monthly, '2026-09-15').dueDates('2026-11-20'), ['2026-09-15', '2026-10-15', '2026-11-15']);
    });

    test('nothing is due before the start date', () {
      expect(rule(Frequency.monthly, '2026-12-01').dueDates('2026-11-20'), isEmpty);
    });

    test('weekly steps by seven days', () {
      expect(rule(Frequency.weekly, '2026-11-01').dueDates('2026-11-20'), ['2026-11-01', '2026-11-08', '2026-11-15']);
    });

    test('yearly', () {
      expect(rule(Frequency.yearly, '2024-03-01').dueDates('2026-11-20'), ['2024-03-01', '2025-03-01', '2026-03-01']);
    });

    test('month end rules keep the original day when the month is long enough', () {
      expect(rule(Frequency.monthly, '2026-01-31').dueDates('2026-04-30'), ['2026-01-31', '2026-02-28', '2026-03-31', '2026-04-30']);
    });

    test('end date stops the rule', () {
      expect(rule(Frequency.monthly, '2026-01-10', end: '2026-03-10').dueDates('2026-12-31'), ['2026-01-10', '2026-02-10', '2026-03-10']);
    });

    test('lastRun skips what already exists', () {
      expect(rule(Frequency.monthly, '2026-09-15', last: '2026-10-15').dueDates('2026-11-20'), ['2026-11-15']);
    });
  });

  group('store', () {
    test('running twice does not duplicate entries', () {
      final s = Store('x', persist: false);
      s.addRecurring(category: 'rent', amount: -500, frequency: Frequency.monthly, startDate: '2026-09-01');
      expect(s.runRecurring('2026-11-10').length, 3);
      expect(s.runRecurring('2026-11-10').length, 0);
      expect(s.runRecurring('2026-12-02').length, 1);
      expect(s.list().length, 4);
    });

    test('generated entries point back at their rule', () {
      final s = Store('x', persist: false);
      final r = s.addRecurring(category: 'salary', amount: 900, frequency: Frequency.monthly, startDate: '2026-11-01');
      s.runRecurring('2026-11-05');
      expect(s.list().single.recurringId, r.id);
    });

    test('removing a rule keeps entries already created', () {
      final s = Store('x', persist: false);
      final r = s.addRecurring(category: 'gym', amount: -20, frequency: Frequency.weekly, startDate: '2026-11-01');
      s.runRecurring('2026-11-10');
      expect(s.removeRecurring(r.id), isTrue);
      expect(s.list().length, 2);
      expect(s.removeRecurring(r.id), isFalse);
    });
  });
}
