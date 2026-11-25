import 'dart:convert';
import 'package:ledgerline/report.dart';
import 'package:ledgerline/server.dart';
import 'package:ledgerline/store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  final rows = [Entry(1, '2026-11-01', 'salary', 'Nov, pay', 900), Entry(2, '2026-11-02', 'food', 'lunch', -12.5)];
  test('csv escapes commas', () => expect(toCsv(rows), contains('"Nov, pay"')));
  test('totals group by category', () => expect(totalsByCategory(rows), {'salary': 900.0, 'food': -12.5}));
  test('balance adds income and expenses', () => expect(balance(rows), 887.5));
  test('table has header and rows', () => expect(toTable(rows).split('\n').length, 4));

  group('service', () {
    final h = buildHandler(Store('${DateTime.now().microsecondsSinceEpoch}-test.json'), 'k');
    Request req(String m, String p, {String? key = 'k', String? body}) =>
        Request(m, Uri.parse('http://x$p'), headers: {if (key != null) 'x-api-key': key}, body: body);
    test('rejects missing key', () async => expect((await h(req('GET', '/entries', key: null))).statusCode, 401));
    test('health is open', () async => expect((await h(req('GET', '/health', key: null))).statusCode, 200));
    test('rejects zero amount', () async =>
        expect((await h(req('POST', '/entries', body: jsonEncode({'category': 'a', 'amount': 0})))).statusCode, 400));
  });
}
