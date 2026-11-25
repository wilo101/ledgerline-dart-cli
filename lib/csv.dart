import 'dates.dart';
import 'models/entry.dart';

/// Parses CSV with quoted fields, escaped quotes and newlines inside quotes.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var i = 0;
  void endCell() {
    row.add(cell.toString());
    cell.clear();
  }

  void endRow() {
    endCell();
    if (!(row.length == 1 && row.first.trim().isEmpty)) rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == ',') {
      endCell();
    } else if (c == '\n') {
      endRow();
    } else if (c != '\r') {
      cell.write(c);
    }
    i++;
  }
  if (cell.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

class ImportRow {
  ImportRow(this.line, this.entry, this.error);
  final int line;
  final Entry? entry;
  final String? error;
}

class ImportResult {
  ImportResult(this.rows);
  final List<ImportRow> rows;
  List<Entry> get entries => [for (final r in rows) if (r.entry != null) r.entry!];
  List<ImportRow> get errors => [for (final r in rows) if (r.error != null) r];
}

/// Reads entries from CSV. Needs `date`, `category` and `amount` columns (any order, any case);
/// `note` and `tags` (separated by `;`) are optional. Bad rows are reported by line number, not dropped silently.
ImportResult importCsv(String text) {
  final table = parseCsv(text);
  if (table.isEmpty) return ImportResult([]);
  final header = [for (final h in table.first) h.trim().toLowerCase()];
  for (final need in ['date', 'category', 'amount']) {
    if (!header.contains(need)) throw FormatException('Missing required column: $need');
  }
  int col(String n) => header.indexOf(n);
  final out = <ImportRow>[];
  for (var i = 1; i < table.length; i++) {
    final r = table[i];
    final line = i + 1;
    String cell(String n) => col(n) >= 0 && col(n) < r.length ? r[col(n)].trim() : '';
    final date = cell('date');
    final category = cell('category');
    final amount = double.tryParse(cell('amount').replaceAll(RegExp(r'[\s$]'), ''));
    if (!isDate(date)) {
      out.add(ImportRow(line, null, 'bad date "$date"'));
    } else if (category.isEmpty) {
      out.add(ImportRow(line, null, 'category is empty'));
    } else if (amount == null || amount == 0) {
      out.add(ImportRow(line, null, 'bad amount "${cell('amount')}"'));
    } else {
      final tags = cell('tags').isEmpty ? <String>[] : cell('tags').split(';').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      out.add(ImportRow(line, Entry(0, date, category, cell('note'), amount, tags: tags), null));
    }
  }
  return ImportResult(out);
}
