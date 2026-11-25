# Changelog

## 2.0.0
- Budgets: monthly limit per category, status per month (ok, warning at 80 percent, over at 100 percent).
- Recurring entries: weekly, monthly and yearly rules with start and end dates. Running them twice never duplicates entries. Month-end dates are clamped (Jan 31 then Feb 28).
- CSV import with a dry run, line-numbered errors and duplicate skipping. CSV export with filters.
- Filters on list, summary and export: category, date range, text, tag, income or expense, amount range.
- Edit and delete entries. Tags on entries.
- Monthly report in the terminal, spending breakdown by category, income and expenses by month.
- Paging on the service (`limit`, `offset`, `x-total-count`).
- Tests split by area: dates, CSV, budgets, recurring rules, store, HTTP service.

## 1.0.0
- Add, list, summary, CSV export and the local HTTP service.
