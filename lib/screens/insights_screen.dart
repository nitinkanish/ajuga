import 'package:flutter/material.dart';

import '../category_style.dart';
import '../ledger.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/app_header.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = ExpenseScope.of(context);
    final code = ledger.currencyCode;
    final now = DateTime.now();
    final from = startOfMonth(now);
    final to = startOfNextMonth(now);
    final spent = ledger.sum(income: false, from: from, to: to);
    final previousFrom = DateTime(now.year, now.month - 1);
    final previous = ledger.sum(income: false, from: previousFrom, to: from);
    final categories = ledger.spentByCategory(from, to);
    final ranked = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = ranked.isEmpty ? 1.0 : ranked.first.value;
    final under = spent <= previous;
    return AppPage(
      header: PageHeader(
        title: 'Insights',
        onBack: () => Navigator.pop(context),
        below: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Spent in ${fullMonths[now.month - 1]}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              formatMoney(spent, code),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              monthDelta(spent, previous),
              style: TextStyle(
                color: under ? const Color(0xFF8DFFC8) : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  Text(
                    'Showing ${ledger.currency.name}',
                    style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 18),
                  const Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  if (ranked.isEmpty)
                    const Text('No spending yet.', style: TextStyle(color: AppColors.muted))
                  else
                    for (final item in ranked) ...[
                      Row(
                        children: [
                          Icon(styleFor(item.key).icon, size: 16, color: styleFor(item.key).foreground),
                          const SizedBox(width: 8),
                          Expanded(child: Text(item.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Text(formatMoney(item.value, code)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: item.value / maxValue,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFF0F2F7),
                          color: styleFor(item.key).foreground,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  const SizedBox(height: 8),
                  const Text('Budgets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final budget in ledger.budgets.entries)
                    _BudgetRow(
                      name: budget.key,
                      spent: categories[budget.key] ?? 0,
                      budget: budget.value,
                      code: code,
                    ),
                ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.name,
    required this.spent,
    required this.budget,
    required this.code,
  });

  final String name;
  final double spent;
  final double budget;
  final String code;

  @override
  Widget build(BuildContext context) {
    final progress = budget == 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);
    final over = spent > budget;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600))),
              Text(
                '${formatMoney(spent, code)} of ${formatMoney(budget, code)}',
                style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: const Color(0xFFF0F2F7),
              color: over ? AppColors.danger : const Color(0xFF2457D6),
            ),
          ),
        ],
      ),
    );
  }
}
