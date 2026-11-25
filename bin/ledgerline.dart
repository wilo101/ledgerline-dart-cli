import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:ledgerline/client.dart';
import 'package:ledgerline/report.dart';
import 'package:ledgerline/server.dart';
import 'package:ledgerline/store.dart';
import 'package:shelf/shelf_io.dart' as io;

String get _key => Platform.environment['LEDGERLINE_KEY'] ?? 'dev-key';

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>('ledgerline', 'A personal ledger: CLI plus its own local service.')
    ..argParser.addOption('url', defaultsTo: Platform.environment['LEDGERLINE_URL'] ?? 'http://localhost:7070')
    ..addCommand(_Serve())
    ..addCommand(_Add())
    ..addCommand(_List())
    ..addCommand(_Summary());
  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  } on StateError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  }
}

LedgerClient _client(Command c) => LedgerClient(c.globalResults!['url'] as String, _key);

class _Serve extends Command<void> {
  _Serve() {
    argParser
      ..addOption('port', defaultsTo: '7070')
      ..addOption('data', defaultsTo: 'ledger.json');
  }
  @override
  final name = 'serve';
  @override
  final description = 'Start the local ledger service.';
  @override
  Future<void> run() async {
    final store = Store(argResults!['data'] as String)..load();
    final server = await io.serve(buildHandler(store, _key), InternetAddress.loopbackIPv4, int.parse(argResults!['port'] as String));
    stdout.writeln('Ledgerline listening on :${server.port}');
  }
}

class _Add extends Command<void> {
  _Add() {
    argParser
      ..addOption('category', mandatory: true)
      ..addOption('amount', mandatory: true, help: 'positive = income, negative = expense')
      ..addOption('note', defaultsTo: '');
  }
  @override
  final name = 'add';
  @override
  final description = 'Add an entry.';
  @override
  Future<void> run() async {
    final amount = double.tryParse(argResults!['amount'] as String);
    if (amount == null || amount == 0) throw UsageException('amount must be a non-zero number', usage);
    final e = await _client(this).add(argResults!['category'] as String, amount, argResults!['note'] as String);
    stdout.writeln('Added entry ${e.id}.');
  }
}

class _List extends Command<void> {
  _List() {
    argParser
      ..addOption('category')
      ..addOption('format', allowed: ['table', 'csv'], defaultsTo: 'table')
      ..addOption('out', help: 'write to a file instead of stdout');
  }
  @override
  final name = 'list';
  @override
  final description = 'Print or export entries.';
  @override
  Future<void> run() async {
    final rows = await _client(this).list(category: argResults!['category'] as String?);
    final text = argResults!['format'] == 'csv' ? toCsv(rows) : toTable(rows);
    final out = argResults!['out'] as String?;
    out == null ? stdout.write(text) : File(out).writeAsStringSync(text);
  }
}

class _Summary extends Command<void> {
  @override
  final name = 'summary';
  @override
  final description = 'Balance and totals by category.';
  @override
  Future<void> run() async {
    final s = await _client(this).summary();
    (s['byCategory'] as Map<String, dynamic>).forEach((k, v) => stdout.writeln('${k.padRight(12)} ${(v as num).toStringAsFixed(2).padLeft(9)}'));
    stdout.writeln('\nBalance      ${(s['balance'] as num).toStringAsFixed(2).padLeft(9)}   (${s['count']} entries)');
  }
}
