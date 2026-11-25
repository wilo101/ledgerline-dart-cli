import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/entry.dart';
import 'models/entry_filter.dart';

class LedgerClient {
  LedgerClient(this.baseUrl, this.apiKey, {http.Client? client}) : _c = client ?? http.Client();
  final String baseUrl, apiKey;
  final http.Client _c;

  Map<String, String> get _h => {'x-api-key': apiKey, 'Content-Type': 'application/json'};

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('$baseUrl$path').replace(queryParameters: q);

  dynamic _ok(http.Response r, int expected, String what) {
    if (r.statusCode != expected) {
      var detail = '';
      try {
        detail = ': ${(jsonDecode(r.body) as Map)['error']}';
      } catch (_) {}
      throw StateError('$what failed (${r.statusCode})$detail');
    }
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  Future<List<Entry>> list({String? category}) => query(EntryFilter(category: category));

  Future<List<Entry>> query(EntryFilter f) async {
    final r = await _c.get(_u('/entries', f.toQuery()), headers: _h);
    return [for (final j in _ok(r, 200, 'Request') as List) Entry.fromJson(j as Map<String, dynamic>)];
  }

  Future<Entry> add(String category, double amount, String note, {String? date, List<String> tags = const []}) async {
    final r = await _c.post(_u('/entries'),
        headers: _h, body: jsonEncode({'category': category, 'amount': amount, 'note': note, if (date != null) 'date': date, 'tags': tags}));
    return Entry.fromJson(_ok(r, 201, 'Create') as Map<String, dynamic>);
  }

  Future<Entry> edit(int id, Map<String, dynamic> changes) async {
    final r = await _c.patch(_u('/entries/$id'), headers: _h, body: jsonEncode(changes));
    return Entry.fromJson(_ok(r, 200, 'Edit') as Map<String, dynamic>);
  }

  Future<void> remove(int id) async => _ok(await _c.delete(_u('/entries/$id'), headers: _h), 200, 'Delete');

  Future<Map<String, dynamic>> summary({EntryFilter? filter}) async =>
      _ok(await _c.get(_u('/summary', filter?.toQuery()), headers: _h), 200, 'Request') as Map<String, dynamic>;

  Future<Map<String, dynamic>> importCsv(String csv, {bool dryRun = false}) async {
    final r = await _c.post(_u('/entries/import', {if (dryRun) 'dry_run': '1'}), headers: {..._h, 'Content-Type': 'text/csv'}, body: csv);
    return _ok(r, 200, 'Import') as Map<String, dynamic>;
  }

  Future<String> exportCsv(EntryFilter f) async {
    final r = await _c.get(_u('/entries/export.csv', f.toQuery()), headers: _h);
    _ok(r, 200, 'Export');
    return r.body;
  }

  Future<List<dynamic>> budgets({String? month}) async =>
      _ok(await _c.get(_u('/budgets', {if (month != null) 'month': month}), headers: _h), 200, 'Request') as List;

  Future<void> setBudget(String category, double limit) async => _ok(
      await _c.put(_u('/budgets/${Uri.encodeComponent(category)}'), headers: _h, body: jsonEncode({'monthlyLimit': limit})), 200, 'Set budget');

  Future<void> removeBudget(String category) async =>
      _ok(await _c.delete(_u('/budgets/${Uri.encodeComponent(category)}'), headers: _h), 200, 'Remove budget');

  Future<List<dynamic>> recurring() async => _ok(await _c.get(_u('/recurring'), headers: _h), 200, 'Request') as List;

  Future<Map<String, dynamic>> addRecurring(Map<String, dynamic> rule) async =>
      _ok(await _c.post(_u('/recurring'), headers: _h, body: jsonEncode(rule)), 201, 'Create rule') as Map<String, dynamic>;

  Future<void> removeRecurring(int id) async => _ok(await _c.delete(_u('/recurring/$id'), headers: _h), 200, 'Remove rule');

  Future<int> runRecurring() async =>
      (_ok(await _c.post(_u('/recurring/run'), headers: _h), 200, 'Run') as Map<String, dynamic>)['created'] as int;

  Future<List<dynamic>> monthly() async => _ok(await _c.get(_u('/reports/monthly'), headers: _h), 200, 'Request') as List;

  Future<List<dynamic>> categories() async => _ok(await _c.get(_u('/categories'), headers: _h), 200, 'Request') as List;
}
