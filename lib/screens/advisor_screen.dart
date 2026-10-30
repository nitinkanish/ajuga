import 'package:flutter/material.dart';

import '../advisor.dart';
import '../ledger.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/pressable.dart';
import 'composer_screen.dart';

class AdvisorScreen extends StatelessWidget {
  const AdvisorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ledger = ExpenseScope.of(context);
    final brief = briefFor(ledger);
    final code = ledger.currencyCode;
    return AppPage(
      header: PageHeader(
        title: 'Ajuga AI',
        subtitle: brief.summary,
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  Row(
                    children: [
                      Expanded(child: _Stat(label: 'Spent', value: formatMoney(brief.spent, code))),
                      const SizedBox(width: 10),
                      Expanded(child: _Stat(label: 'Credit', value: formatMoney(brief.credit, code))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _Stat(
                    label: 'Safe to spend each day',
                    value: formatMoney(brief.safePerDay, code),
                    wide: true,
                  ),
                  const SizedBox(height: 22),
                  const Text('Recommendations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  for (final item in brief.advice) ...[
                    _AdviceCard(advice: item),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 8),
                  PillButton(
                    label: 'Add an expense',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ComposerScreen(kind: ComposerKind.expense),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  PillButton(
                    label: 'Add a credit',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ComposerScreen(kind: ComposerKind.income),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Recommendations are calculated on this phone from your balance, budget, and transactions. Nothing is sent to a server.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4),
                  ),
                ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.wide = false});

  final String label;
  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: wide ? 26 : 18, fontWeight: FontWeight.w700, letterSpacing: -0.4),
          ),
        ],
      ),
    );
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice});

  final Advice advice;

  @override
  Widget build(BuildContext context) {
    final color = switch (advice.tone) {
      AdviceTone.good => AppColors.positive,
      AdviceTone.watch => const Color(0xFFB7791F),
      AdviceTone.alert => AppColors.danger,
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(advice.title, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 15.5)),
          const SizedBox(height: 6),
          Text(advice.body, style: const TextStyle(height: 1.4, fontSize: 14)),
        ],
      ),
    );
  }
}
