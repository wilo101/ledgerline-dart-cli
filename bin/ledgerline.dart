import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:ledgerline/client.dart';
import 'package:ledgerline/dates.dart';
import 'package:ledgerline/models/budget.dart';
import 'package:ledgerline/models/entry_filter.dart';
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
    ..addCommand(_Edit())
    ..addCommand(_Delete())
    ..addCommand(_List())
    ..addCommand(_Summary())
    ..addCommand(_Report())
    ..addCommand(_Budget())
    ..addCommand(_Recurring())
    ..addCommand(_Import())
    ..addCommand(_Categories());
  try {
    await runner.run(args);
  } on UsageException catch (e) {
    stderr.writeln(e);
    exit(64);
  } on StateError catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(1);
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    exit(65);
  }
}

LedgerClient _client(Command c) {
  Command? cur = c;
  while (cur?.parent != null) {
    cur = cur!.parent;
  }
  return LedgerClient(cur!.globalResults!['url'] as String, _key);
}

EntryFilter _filterFrom(dynamic r) => EntryFilter(
      category: r['category'] as String?,
      from: r['from'] as String?,
      to: r['to'] as String?,
      text: r['search'] as String?,
      tag: r['tag'] as String?,
      type: r['type'] as String?,
      minAmount: double.tryParse('${r['min'] ?? ''}'),
      maxAmount: double.tryParse('${r['max'] ?? ''}'),
    );

void _filterOptions(ArgParser p) => p
  ..addOption('category')
  ..addOption('from', help: 'YYYY-MM-DD')
  ..addOption('to', help: 'YYYY-MM-DD')
  ..addOption('search', help: 'text in note or category')
  ..addOption('tag')
  ..addOption('type', allowed: ['income', 'expense'])
  ..addOption('min', help: 'smallest amount, ignoring sign')
  ..addOption('max', help: 'largest amount, ignoring sign');

class _Serve extends Command<void> {
  _Serve() {
    argParser
      ..addOption('port', defaultsTo: '7070')
      ..addOption('data', defaultsTo: 'ledger.json')
      ..addFlag('recurring', defaultsTo: true, help: 'create due recurring entries on start');
  }
  @override
  final name = 'serve';
  @override
  final description = 'Start the local ledger service.';
  @override
  Future<void> run() async {
    final store = Store(argResults!['data'] as String)..load();
    if (argResults!['recurring'] as bool) {
      final n = store.runRecurring().length;
      if (n > 0) stdout.writeln('Created $n recurring entries.');
    }
    final server = await io.serve(buildHandler(store, _key), InternetAddress.loopbackIPv4, int.parse(argResults!['port'] as String));
    stdout.writeln('Ledgerline listening on :${server.port}');
  }
}

class _Add extends Command<void> {
  _Add() {
    argParser
      ..addOption('category', mandatory: true)
      ..addOption('amount', mandatory: true, help: 'positive = income, negative = expense')
      ..addOption('note', defaultsTo: '')
      ..addOption('date', help: 'YYYY-MM-DD, default today')
      ..addMultiOption('tag');
  }
  @override
  final name = 'add';
  @override
  final description = 'Add an entry.';
  @override
  Future<void> run() async {
    final amount = double.tryParse(argResults!['amount'] as String);
    if (amount == null || amount == 0) throw UsageException('amount must be a non-zero number', usage);
    final date = argResults!['date'] as String?;
    if (date != null && !isDate(date)) throw UsageException('date must be YYYY-MM-DD', usage);
    final e = await _client(this).add(argResults!['category'] as String, amount, argResults!['note'] as String,
        date: date, tags: argResults!['tag'] as List<String>);
    stdout.writeln('Added entry ${e.id}.');
  }
}

class _Edit extends Command<void> {
  _Edit() {
    argParser
      ..addOption('category')
      ..addOption('amount')
      ..addOption('note')
      ..addOption('date');
  }
  @override
  final name = 'edit';
  @override
  final description = 'Change an entry: edit <id> --amount -20.';
  @override
  Future<void> run() async {
    final id = int.tryParse(argResults!.rest.isEmpty ? '' : argResults!.rest.first);
    if (id == null) throw UsageException('give the entry id', usage);
    final changes = <String, dynamic>{
      for (final k in ['category', 'note', 'date'])
        if (argResults![k] != null) k: argResults![k],
      if (argResults!['amount'] != null) 'amount': double.parse(argResults!['amount'] as String),
    };
    if (changes.isEmpty) throw UsageException('nothing to change', usage);
    await _client(this).edit(id, changes);
    stdout.writeln('Updated entry $id.');
  }
}

class _Delete extends Command<void> {
  @override
  final name = 'delete';
  @override
  final description = 'Remove an entry: delete <id>.';
  @override
  Future<void> run() async {
    final id = int.tryParse(argResults!.rest.isEmpty ? '' : argResults!.rest.first);
    if (id == null) throw UsageException('give the entry id', usage);
    await _client(this).remove(id);
    stdout.writeln('Deleted entry $id.');
  }
}

class _List extends Command<void> {
  _List() {
    _filterOptions(argParser);
    argParser
      ..addOption('format', allowed: ['table', 'csv'], defaultsTo: 'table')
      ..addOption('out', help: 'write to a file instead of stdout');
  }
  @override
  final name = 'list';
  @override
  final description = 'Print or export entries, with filters.';
  @override
  Future<void> run() async {
    final rows = await _client(this).query(_filterFrom(argResults!));
    final text = argResults!['format'] == 'csv' ? toCsv(rows) : toTable(rows);
    final out = argResults!['out'] as String?;
    out == null ? stdout.write(text) : File(out).writeAsStringSync(text);
  }
}

class _Summary extends Command<void> {
  _Summary() {
    _filterOptions(argParser);
  }
  @override
  final name = 'summary';
  @override
  final description = 'Balance and totals by category (accepts the list filters).';
  @override
  Future<void> run() async {
    final s = await _client(this).summary(filter: _filterFrom(argResults!));
    (s['byCategory'] as Map<String, dynamic>).forEach((k, v) => stdout.writeln('${k.padRight(12)} ${(v as num).toStringAsFixed(2).padLeft(9)}'));
    stdout.writeln('\nIncome       ${(s['income'] as num).toStringAsFixed(2).padLeft(9)}');
    stdout.writeln('Expenses     ${(s['expenses'] as num).toStringAsFixed(2).padLeft(9)}');
    stdout.writeln('Balance      ${(s['balance'] as num).toStringAsFixed(2).padLeft(9)}   (${s['count']} entries)');
  }
}

class _Report extends Command<void> {
  _Report() {
    argParser.addOption('month', help: 'YYYY-MM, default this month');
  }
  @override
  final name = 'report';
  @override
  final description = 'Monthly report: totals, spending by category and budgets.';
  @override
  Future<void> run() async {
    final c = _client(this);
    final month = (argResults!['month'] as String?) ?? monthNow();
    final rows = await c.list();
    final budgets = [for (final b in await c.budgets(month: month)) Budget('${b['category']}', (b['limit'] as num).toDouble())];
    stdout.write(monthlyReport(rows, budgets, month));
  }
}

class _Budget extends Command<void> {
  _Budget() {
    addSubcommand(_BudgetSet());
    addSubcommand(_BudgetList());
    addSubcommand(_BudgetRemove());
  }
  @override
  final name = 'budget';
  @override
  final description = 'Monthly budgets per category.';
}

class _BudgetSet extends Command<void> {
  @override
  final name = 'set';
  @override
  final description = 'budget set <category> <monthly limit>';
  @override
  Future<void> run() async {
    final r = argResults!.rest;
    final limit = r.length == 2 ? double.tryParse(r[1]) : null;
    if (limit == null || limit <= 0) throw UsageException('usage: budget set <category> <positive limit>', usage);
    await _client(this).setBudget(r[0], limit);
    stdout.writeln('Budget for ${r[0]} set to ${limit.toStringAsFixed(2)} a month.');
  }
}

class _BudgetList extends Command<void> {
  _BudgetList() {
    argParser.addOption('month', help: 'YYYY-MM, default this month');
  }
  @override
  final name = 'list';
  @override
  final description = 'Show how each budget is doing.';
  @override
  Future<void> run() async {
    final rows = await _client(this).budgets(month: argResults!['month'] as String?);
    if (rows.isEmpty) stdout.writeln('No budgets yet. Try: budget set food 300');
    for (final b in rows) {
      final pct = (b['percent'] as num).toStringAsFixed(0).padLeft(4);
      stdout.writeln('${('${b['category']}').padRight(12)} ${(b['spent'] as num).toStringAsFixed(2).padLeft(9)} / ${(b['limit'] as num).toStringAsFixed(2).padLeft(9)} $pct%  ${b['level']}');
    }
  }
}

class _BudgetRemove extends Command<void> {
  @override
  final name = 'remove';
  @override
  final description = 'budget remove <category>';
  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) throw UsageException('give the category', usage);
    await _client(this).removeBudget(argResults!.rest.first);
    stdout.writeln('Removed budget.');
  }
}

class _Recurring extends Command<void> {
  _Recurring() {
    addSubcommand(_RecAdd());
    addSubcommand(_RecList());
    addSubcommand(_RecRemove());
    addSubcommand(_RecRun());
  }
  @override
  final name = 'recurring';
  @override
  final description = 'Rules that create entries on a schedule.';
}

class _RecAdd extends Command<void> {
  _RecAdd() {
    argParser
      ..addOption('category', mandatory: true)
      ..addOption('amount', mandatory: true)
      ..addOption('every', allowed: ['weekly', 'monthly', 'yearly'], mandatory: true)
      ..addOption('start', help: 'YYYY-MM-DD, default today')
      ..addOption('end', help: 'YYYY-MM-DD, optional')
      ..addOption('note', defaultsTo: '');
  }
  @override
  final name = 'add';
  @override
  final description = 'Add a rule, e.g. rent every month.';
  @override
  Future<void> run() async {
    final amount = double.tryParse(argResults!['amount'] as String);
    if (amount == null || amount == 0) throw UsageException('amount must be a non-zero number', usage);
    final r = await _client(this).addRecurring({
      'category': argResults!['category'],
      'amount': amount,
      'frequency': argResults!['every'],
      'startDate': argResults!['start'] ?? fmtDate(DateTime.now()),
      'endDate': argResults!['end'],
      'note': argResults!['note'],
    });
    stdout.writeln('Added rule ${r['id']}. Run "recurring run" to create what is due.');
  }
}

class _RecList extends Command<void> {
  @override
  final name = 'list';
  @override
  final description = 'List rules.';
  @override
  Future<void> run() async {
    final rules = await _client(this).recurring();
    if (rules.isEmpty) stdout.writeln('No recurring rules.');
    for (final r in rules) {
      stdout.writeln('${('${r['id']}').padRight(4)} ${('${r['category']}').padRight(12)} ${(r['amount'] as num).toStringAsFixed(2).padLeft(9)}  ${r['frequency']} from ${r['startDate']}'
          '${r['endDate'] != null ? ' to ${r['endDate']}' : ''}  last: ${r['lastRun'] ?? 'never'}');
    }
  }
}

class _RecRemove extends Command<void> {
  @override
  final name = 'remove';
  @override
  final description = 'recurring remove <id>';
  @override
  Future<void> run() async {
    final id = int.tryParse(argResults!.rest.isEmpty ? '' : argResults!.rest.first);
    if (id == null) throw UsageException('give the rule id', usage);
    await _client(this).removeRecurring(id);
    stdout.writeln('Removed rule $id.');
  }
}

class _RecRun extends Command<void> {
  @override
  final name = 'run';
  @override
  final description = 'Create every entry that is due. Safe to run again.';
  @override
  Future<void> run() async => stdout.writeln('Created ${await _client(this).runRecurring()} entries.');
}

class _Import extends Command<void> {
  _Import() {
    argParser.addFlag('dry-run', negatable: false, help: 'check the file without saving');
  }
  @override
  final name = 'import';
  @override
  final description = 'Import entries from a CSV file (columns: date, category, amount, note, tags).';
  @override
  Future<void> run() async {
    if (argResults!.rest.isEmpty) throw UsageException('give a CSV file', usage);
    final file = File(argResults!.rest.first);
    if (!file.existsSync()) throw StateError('No such file: ${file.path}');
    final r = await _client(this).importCsv(file.readAsStringSync(), dryRun: argResults!['dry-run'] as bool);
    stdout.writeln('${r['dryRun'] == true ? 'Would add' : 'Added'} ${r['added']} entries, ${r['duplicates']} duplicates skipped.');
    for (final e in r['errors'] as List) {
      stdout.writeln('  line ${e['line']}: ${e['error']}');
    }
    if ((r['errors'] as List).isNotEmpty) exit(2);
  }
}

class _Categories extends Command<void> {
  @override
  final name = 'categories';
  @override
  final description = 'List categories in use.';
  @override
  Future<void> run() async => (await _client(this).categories()).forEach(stdout.writeln);
}
