import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'report.dart';
import 'store.dart';

Response _json(Object body, [int status = 200]) =>
    Response(status, body: jsonEncode(body), headers: {'content-type': 'application/json'});

/// Requests need the header `x-api-key: <apiKey>` (except /health).
Handler buildHandler(Store store, String apiKey) {
  final router = Router();
  router.get('/health', (Request r) => _json({'ok': true}));

  router.get('/entries', (Request r) =>
      _json([for (final e in store.list(category: r.url.queryParameters['category'])) e.toJson()]));

  router.post('/entries', (Request r) async {
    final b = jsonDecode(await r.readAsString()) as Map<String, dynamic>;
    final amount = (b['amount'] as num?)?.toDouble();
    if (b['category'] == null || amount == null || amount == 0) {
      return _json({'error': 'category and a non-zero amount are required'}, 400);
    }
    return _json(store.add('${b['category']}', '${b['note'] ?? ''}', amount, b['date'] as String?).toJson(), 201);
  });

  router.delete('/entries/<id>', (Request r, String id) {
    final ok = int.tryParse(id) != null && store.remove(int.parse(id));
    return ok ? _json({'ok': true}) : _json({'error': 'not found'}, 404);
  });

  router.get('/summary', (Request r) {
    final all = store.list();
    return _json({'balance': balance(all), 'count': all.length, 'byCategory': totalsByCategory(all)});
  });

  return Pipeline().addMiddleware((inner) => (req) {
        if (req.url.path == 'health' || req.headers['x-api-key'] == apiKey) return inner(req);
        return _json({'error': 'missing or wrong api key'}, 401);
      }).addMiddleware(logRequests()).addHandler(router.call);
}
