import 'entry.dart';

/// Query used by the list command and the `/entries` endpoint.
class EntryFilter {
  const EntryFilter({this.category, this.from, this.to, this.text, this.minAmount, this.maxAmount, this.tag, this.type});

  factory EntryFilter.fromQuery(Map<String, String> q) => EntryFilter(
        category: q['category'],
        from: q['from'],
        to: q['to'],
        text: q['q'],
        minAmount: double.tryParse(q['min'] ?? ''),
        maxAmount: double.tryParse(q['max'] ?? ''),
        tag: q['tag'],
        type: q['type'],
      );

  final String? category, from, to, text, tag;

  /// `income` or `expense`.
  final String? type;
  final double? minAmount, maxAmount;

  bool matches(Entry e) {
    if (category != null && e.category != category) return false;
    if (from != null && e.date.compareTo(from!) < 0) return false;
    if (to != null && e.date.compareTo(to!) > 0) return false;
    if (tag != null && !e.tags.contains(tag)) return false;
    if (type == 'income' && e.amount <= 0) return false;
    if (type == 'expense' && e.amount >= 0) return false;
    if (minAmount != null && e.amount.abs() < minAmount!) return false;
    if (maxAmount != null && e.amount.abs() > maxAmount!) return false;
    if (text != null && text!.isNotEmpty) {
      final t = text!.toLowerCase();
      if (!e.note.toLowerCase().contains(t) && !e.category.toLowerCase().contains(t)) return false;
    }
    return true;
  }

  Map<String, String> toQuery() => {
        if (category != null) 'category': category!,
        if (from != null) 'from': from!,
        if (to != null) 'to': to!,
        if (text != null) 'q': text!,
        if (minAmount != null) 'min': '$minAmount',
        if (maxAmount != null) 'max': '$maxAmount',
        if (tag != null) 'tag': tag!,
        if (type != null) 'type': type!,
      };
}
