import 'dart:convert';
import 'package:http/http.dart' as http;
import 'report.dart';

class LedgerClient {
  LedgerClient(this.baseUrl, this.apiKey, {http.Client? client}) : _c = client ?? http.Client();
  final String baseUrl, apiKey;
  final http.Client _c;

  Map<String, String> get _h => {'x-api-key': apiKey, 'Content-Type': 'application/json'};

  Future<List<Entry>> list({String? category}) async {
    final uri = Uri.parse('$baseUrl/entries').replace(queryParameters: {if (category != null) 'category': category});
    final r = await _c.get(uri, headers: _h);
    if (r.statusCode != 200) throw StateError('Request failed (${r.statusCode}). Is the server running?');
    return [for (final j in jsonDecode(r.body) as List) Entry.fromJson(j as Map<String, dynamic>)];
  }

  Future<Entry> add(String category, double amount, String note) async {
    final r = await _c.post(Uri.parse('$baseUrl/entries'),
        headers: _h, body: jsonEncode({'category': category, 'amount': amount, 'note': note}));
    if (r.statusCode != 201) throw StateError('Create failed (${r.statusCode})');
    return Entry.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> summary() async {
    final r = await _c.get(Uri.parse('$baseUrl/summary'), headers: _h);
    if (r.statusCode != 200) throw StateError('Request failed (${r.statusCode})');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}
