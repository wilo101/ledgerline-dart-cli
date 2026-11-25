/// A monthly spending limit for one category.
class Budget {
  Budget(this.category, this.monthlyLimit);

  factory Budget.fromJson(Map<String, dynamic> j) => Budget('${j['category']}', (j['monthlyLimit'] as num).toDouble());

  final String category;
  final double monthlyLimit;

  Map<String, dynamic> toJson() => {'category': category, 'monthlyLimit': monthlyLimit};
}

enum BudgetLevel { ok, warning, over }

/// How a budget is doing for one month.
class BudgetStatus {
  BudgetStatus(this.budget, this.month, this.spent);

  final Budget budget;
  final String month;

  /// Expenses as a positive number.
  final double spent;

  double get remaining => budget.monthlyLimit - spent;
  double get ratio => budget.monthlyLimit == 0 ? 0 : spent / budget.monthlyLimit;

  /// Warning from 80 percent, over at 100 percent.
  BudgetLevel get level => ratio >= 1 ? BudgetLevel.over : (ratio >= 0.8 ? BudgetLevel.warning : BudgetLevel.ok);

  Map<String, dynamic> toJson() => {
        'category': budget.category,
        'month': month,
        'limit': budget.monthlyLimit,
        'spent': double.parse(spent.toStringAsFixed(2)),
        'remaining': double.parse(remaining.toStringAsFixed(2)),
        'percent': double.parse((ratio * 100).toStringAsFixed(1)),
        'level': level.name,
      };
}
