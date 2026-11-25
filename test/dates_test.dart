import 'package:ledgerline/dates.dart';
import 'package:test/test.dart';

void main() {
  test('formats and parses', () {
    expect(fmtDate(DateTime.utc(2026, 3, 5)), '2026-03-05');
    expect(parseDate('2026-03-05'), DateTime.utc(2026, 3, 5));
  });

  test('rejects impossible dates', () {
    expect(isDate('2026-02-30'), isFalse);
    expect(isDate('2026-13-01'), isFalse);
    expect(isDate('26-1-1'), isFalse);
    expect(isDate('2028-02-29'), isTrue);
  });

  test('addMonths clamps to the end of short months', () {
    expect(addMonths(DateTime.utc(2026, 1, 31), 1), DateTime.utc(2026, 2, 28));
    expect(addMonths(DateTime.utc(2028, 1, 31), 1), DateTime.utc(2028, 2, 29));
    expect(addMonths(DateTime.utc(2026, 11, 15), 3), DateTime.utc(2027, 2, 15));
    expect(addMonths(DateTime.utc(2026, 12, 10), 1), DateTime.utc(2027, 1, 10));
  });

  test('monthOf', () => expect(monthOf('2026-11-25'), '2026-11'));
}
