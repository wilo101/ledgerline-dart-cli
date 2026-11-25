import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'csv.dart';
import 'dates.dart';
import 'models/entry_filter.dart';
import 'models/recurring.dart';
import 'report.dart';
import 'store.dart';

Response _json(Object body, [int status = 200]) =>
    Response(status, body: jsonEncode(body), headers: {'content-type': 'application/json'});

Response _bad(String message, [Map<String, String>? fields]) =>
    _json({'error': message, if (fields != null) 'fields': fields}, 400);

Future<Map<String, dynamic>?> _body(Request r) async {
  try {
    final v = jsonDecode(await r.readAsString());
    return v is Map<String, dynamic> ? v : null;
  } catch (_) {
    return null;
  }
}

/// Requests need the header `x-api-key: <apiKey>` (except /health).
Handler buildHandler(Store store, String apiKey) {
  final router = Router();
  router.get('/health', (Request r) => _json({'ok': true, 'version': '2.0.0'}));

  // ---- entries
  router.get('/entries', (Request r) {
    final rows = store.query(EntryFilter.fromQuery(r.url.queryParameters));
    final limit = int.tryParse(r.url.queryParameters['limit'] ?? '');
    final offset = int.tryParse(r.url.queryParameters['offset'] ?? '') ?? 0;
    final page = rows.skip(offset < 0 ? 0 : offset).take(limit ?? rows.length).toList();
    return Response(200,
        body: jsonEncode([for (final e in page) e.toJson()]),
        headers: {'content-type': 'application/json', 'x-total-count': '${rows.length}'});
  });

  router.get('/entries/export.csv', (Request r) =>
      Response.ok(toCsv(store.query(EntryFilter.fromQuery(r.url.queryParameters))), headers: {'content-type': 'text/csv'}));

  router.get('/entries/<id|[0-9]+>', (Request r, String id) {
    final e = store.get(int.parse(id));
    return e == null ? _json({'error': 'not found'}, 404) : _json(e.toJson());
  });

  router.post('/entries', (Request r) async {
    final b = await _body(r);
    if (b == null) return _bad('body must be a JSON object');
    final amount = (b['amount'] as num?)?.toDouble();
    final date = b['date'] as String?;
    if (b['category'] == null || '${b['category']}'.trim().isEmpty || amount == null || amount == 0) {
      return _bad('category and a non-zero amount are required');
    }
    if (date != null && !isDate(date)) return _bad('date must be YYYY-MM-DD');
    final tags = ((b['tags'] ?? const []) as List).map((e) => '$e').toList();
    return _json(store.add('${b['category']}', '${b['note'] ?? ''}', amount, date, tags).toJson(), 201);
  });

  router.patch('/entries/<id|[0-9]+>', (Request r, String id) async {
    final b = await _body(r);
    if (b == null) return _bad('body must be a JSON object');
    if (b['date'] != null && !isDate('${b['date']}')) return _bad('date must be YYYY-MM-DD');
    final amount = (b['amount'] as num?)?.toDouble();
    if (b.containsKey('amount') && (amount == null || amount == 0)) return _bad('amount must be non-zero');
    final e = store.update(int.parse(id),
        date: b['date'] as String?,
        category: b['category'] as String?,
        note: b['note'] as String?,
        amount: amount,
        tags: b['tags'] is List ? (b['tags'] as List).map((e) => '$e').toList() : null);
    return e == null ? _json({'error': 'not found'}, 404) : _json(e.toJson());
  });

  router.delete('/entries/<id>', (Request r, String id) {
    final ok = int.tryParse(id) != null && store.remove(int.parse(id));
    return ok ? _json({'ok': true}) : _json({'error': 'not found'}, 404);
  });

  /// Body is raw CSV text. Add `?dry_run=1` to validate without saving.
  router.post('/entries/import', (Request r) async {
    final text = await r.readAsString();
    final ImportResult result;
    try {
      result = importCsv(text);
    } on FormatException catch (e) {
      return _bad(e.message);
    }
    final dry = r.url.queryParameters['dry_run'] == '1';
    final skip = r.url.queryParameters['allow_duplicates'] != '1';
    final counts = dry ? (added: result.entries.length, duplicates: 0) : store.addAll(result.entries, skipDuplicates: skip);
    return _json({
      'dryRun': dry,
      'added': counts.added,
      'duplicates': counts.duplicates,
      'errors': [for (final e in result.errors) {'line': e.line, 'error': e.error}],
    });
  });

  // ---- summary and reports
  router.get('/summary', (Request r) {
    final all = store.query(EntryFilter.fromQuery(r.url.queryParameters));
    return _json({
      'balance': balance(all),
      'income': income(all),
      'expenses': expenses(all),
      'count': all.length,
      'byCategory': totalsByCategory(all),
    });
  });

  router.get('/reports/monthly', (Request r) => _json(monthlyTotals(store.list())));

  router.get('/reports/breakdown', (Request r) {
    final month = r.url.queryParameters['month'] ?? monthNow();
    return _json({'month': month, 'categories': spendingBreakdown(store.list(), month)});
  });

  router.get('/categories', (Request r) => _json(store.categories));

  // ---- budgets
  router.get('/budgets', (Request r) {
    final month = r.url.queryParameters['month'] ?? monthNow();
    return _json([for (final s in budgetStatuses(store.budgets, store.list(), month)) s.toJson()]);
  });

  router.put('/budgets/<category>', (Request r, String category) async {
    final b = await _body(r);
    final limit = (b?['monthlyLimit'] as num?)?.toDouble();
    if (limit == null || limit <= 0) return _bad('monthlyLimit must be a positive number');
    return _json(store.setBudget(Uri.decodeComponent(category), limit).toJson());
  });

  router.delete('/budgets/<category>', (Request r, String category) =>
      store.removeBudget(Uri.decodeComponent(category)) ? _json({'ok': true}) : _json({'error': 'not found'}, 404));

  // ---- recurring
  router.get('/recurring', (Request r) => _json([for (final x in store.recurring) x.toJson()]));

  router.post('/recurring', (Request r) async {
    final b = await _body(r);
    if (b == null) return _bad('body must be a JSON object');
    final amount = (b['amount'] as num?)?.toDouble();
    final freq = Frequency.values.where((f) => f.name == b['frequency']).firstOrNull;
    final start = '${b['startDate'] ?? fmtDate(DateTime.now())}';
    final errors = <String, String>{};
    if ('${b['category'] ?? ''}'.trim().isEmpty) errors['category'] = 'required';
    if (amount == null || amount == 0) errors['amount'] = 'must be non-zero';
    if (freq == null) errors['frequency'] = 'weekly, monthly or yearly';
    if (!isDate(start)) errors['startDate'] = 'YYYY-MM-DD';
    if (b['endDate'] != null && !isDate('${b['endDate']}')) errors['endDate'] = 'YYYY-MM-DD';
    if (errors.isNotEmpty) return _bad('validation failed', errors);
    final x = store.addRecurring(
        category: '${b['category']}',
        amount: amount!,
        frequency: freq!,
        startDate: start,
        note: '${b['note'] ?? ''}',
        endDate: b['endDate'] as String?);
    return _json(x.toJson(), 201);
  });

  router.delete('/recurring/<id|[0-9]+>', (Request r, String id) =>
      store.removeRecurring(int.parse(id)) ? _json({'ok': true}) : _json({'error': 'not found'}, 404));

  /// Creates every entry that is due. Safe to call repeatedly.
  router.post('/recurring/run', (Request r) {
    final created = store.runRecurring(r.url.queryParameters['today']);
    return _json({'created': created.length, 'entries': [for (final e in created) e.toJson()]});
  });

  return Pipeline().addMiddleware((inner) => (req) {
        if (req.url.path == 'health' || req.headers['x-api-key'] == apiKey) return inner(req);
        return _json({'error': 'missing or wrong api key'}, 401);
      }).addMiddleware(logRequests()).addHandler(router.call);
}
