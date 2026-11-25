import 'dart:convert';
import 'package:ledgerline/server.dart';
import 'package:ledgerline/store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late Handler h;
  late Store store;
  setUp(() {
    store = Store('x', persist: false);
    h = buildHandler(store, 'k');
  });

  Future<Response> call(String m, String p, {Object? json, String? raw, String? key = 'k'}) => Future.sync(() => h(Request(m, Uri.parse('http://x$p'),
      headers: {if (key != null) 'x-api-key': key}, body: raw ?? (json == null ? null : jsonEncode(json)))));
  Future<dynamic> body(Response r) async => jsonDecode(await r.readAsString());

  test('rejects a missing key, health is open', () async {
    expect((await call('GET', '/entries', key: null)).statusCode, 401);
    expect((await call('GET', '/health', key: null)).statusCode, 200);
  });

  group('entries', () {
    test('create validates', () async {
      expect((await call('POST', '/entries', json: {'category': 'a', 'amount': 0})).statusCode, 400);
      expect((await call('POST', '/entries', json: {'category': ' ', 'amount': 5})).statusCode, 400);
      expect((await call('POST', '/entries', json: {'category': 'a', 'amount': 5, 'date': '2026-02-31'})).statusCode, 400);
      expect((await call('POST', '/entries', raw: 'not json')).statusCode, 400);
      expect((await call('POST', '/entries', json: {'category': 'a', 'amount': -5, 'date': '2026-02-03'})).statusCode, 201);
    });

    test('list filters and reports the total for paging', () async {
      for (var i = 1; i <= 5; i++) {
        await call('POST', '/entries', json: {'category': i.isEven ? 'food' : 'fun', 'amount': -i, 'date': '2026-11-0$i'});
      }
      final r = await call('GET', '/entries?category=food');
      expect((await body(r) as List).length, 2);
      final page = await call('GET', '/entries?limit=2&offset=1');
      expect((await body(page) as List).length, 2);
      expect(page.headers['x-total-count'], '5');
      expect((await body(await call('GET', '/entries?from=2026-11-04')) as List).length, 2);
      expect((await body(await call('GET', '/entries?type=income')) as List), isEmpty);
    });

    test('get, patch and delete', () async {
      final e = await body(await call('POST', '/entries', json: {'category': 'a', 'amount': -5}));
      final id = e['id'];
      expect((await call('GET', '/entries/$id')).statusCode, 200);
      final p = await body(await call('PATCH', '/entries/$id', json: {'amount': -9, 'note': 'fixed'}));
      expect(p['amount'], -9);
      expect(p['note'], 'fixed');
      expect((await call('PATCH', '/entries/$id', json: {'amount': 0})).statusCode, 400);
      expect((await call('PATCH', '/entries/999', json: {'note': 'x'})).statusCode, 404);
      expect((await call('DELETE', '/entries/$id')).statusCode, 200);
      expect((await call('DELETE', '/entries/$id')).statusCode, 404);
    });

    test('summary has income, expenses and balance', () async {
      await call('POST', '/entries', json: {'category': 'salary', 'amount': 900});
      await call('POST', '/entries', json: {'category': 'food', 'amount': -100});
      final s = await body(await call('GET', '/summary'));
      expect(s['income'], 900);
      expect(s['expenses'], 100);
      expect(s['balance'], 800);
    });
  });

  group('import and export', () {
    const csv = 'date,category,amount,note\n2026-11-01,food,-5,a\n2026-11-02,food,-6,b\nbad,food,-1,c\n';

    test('dry run saves nothing', () async {
      final r = await body(await call('POST', '/entries/import?dry_run=1', raw: csv));
      expect(r['added'], 2);
      expect((r['errors'] as List).single['line'], 4);
      expect(store.list(), isEmpty);
    });

    test('import saves good rows, skips duplicates on a second run', () async {
      expect((await body(await call('POST', '/entries/import', raw: csv)))['added'], 2);
      final again = await body(await call('POST', '/entries/import', raw: csv));
      expect(again['added'], 0);
      expect(again['duplicates'], 2);
    });

    test('missing columns give a 400', () async {
      expect((await call('POST', '/entries/import', raw: 'a,b\n1,2')).statusCode, 400);
    });

    test('export returns csv with the filter applied', () async {
      await call('POST', '/entries/import', raw: csv);
      final r = await call('GET', '/entries/export.csv?from=2026-11-02');
      expect(r.headers['content-type'], 'text/csv');
      expect((await r.readAsString()).trim().split('\n').length, 2);
    });
  });

  group('budgets', () {
    test('set, list with status, remove', () async {
      expect((await call('PUT', '/budgets/food', json: {'monthlyLimit': -1})).statusCode, 400);
      expect((await call('PUT', '/budgets/food', json: {'monthlyLimit': 100})).statusCode, 200);
      await call('POST', '/entries', json: {'category': 'food', 'amount': -85, 'date': '2026-11-03'});
      final l = await body(await call('GET', '/budgets?month=2026-11')) as List;
      expect(l.single['level'], 'warning');
      expect(l.single['remaining'], 15);
      expect((await call('DELETE', '/budgets/food')).statusCode, 200);
      expect((await call('DELETE', '/budgets/food')).statusCode, 404);
    });

    test('category names with spaces work', () async {
      await call('PUT', '/budgets/eating%20out', json: {'monthlyLimit': 50});
      expect(store.budgets.single.category, 'eating out');
    });
  });

  group('recurring', () {
    test('validation errors name the fields', () async {
      final r = await call('POST', '/recurring', json: {'category': '', 'amount': 0, 'frequency': 'daily'});
      expect(r.statusCode, 400);
      expect((await body(r))['fields'].keys, containsAll(['category', 'amount', 'frequency']));
    });

    test('create, run and run again', () async {
      await call('POST', '/recurring', json: {'category': 'rent', 'amount': -500, 'frequency': 'monthly', 'startDate': '2026-09-01'});
      final run = await body(await call('POST', '/recurring/run?today=2026-11-15'));
      expect(run['created'], 3);
      expect((await body(await call('POST', '/recurring/run?today=2026-11-15')))['created'], 0);
      expect((await body(await call('GET', '/recurring')) as List).single['lastRun'], '2026-11-01');
    });
  });

  test('monthly report and breakdown', () async {
    await call('POST', '/entries', json: {'category': 'salary', 'amount': 1000, 'date': '2026-10-01'});
    await call('POST', '/entries', json: {'category': 'food', 'amount': -200, 'date': '2026-11-01'});
    final m = await body(await call('GET', '/reports/monthly')) as List;
    expect(m.length, 2);
    final b = await body(await call('GET', '/reports/breakdown?month=2026-11'));
    expect(b['categories'].single['category'], 'food');
    expect(b['categories'].single['share'], 100);
  });
}
