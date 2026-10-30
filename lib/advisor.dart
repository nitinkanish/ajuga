import 'ledger.dart';

enum AdviceTone { good, watch, alert }

class Advice {
  const Advice({required this.title, required this.body, required this.tone});

  final String title;
  final String body;
  final AdviceTone tone;
}

class SpendBrief {
  const SpendBrief({
    required this.summary,
    required this.spent,
    required this.credit,
    required this.leftInBudget,
    required this.safePerDay,
    required this.advice,
  });

  final String summary;
  final double spent;
  final double credit;
  final double leftInBudget;
  final double safePerDay;
  final List<Advice> advice;
}

SpendBrief briefFor(Ledger ledger) {
  final now = DateTime.now();
  final from = startOfMonth(now);
  final to = startOfNextMonth(now);
  final previousFrom = DateTime(now.year, now.month - 1);
  final code = ledger.currencyCode;
  final spent = ledger.sum(income: false, from: from, to: to);
  final credit = ledger.sum(income: true, from: from, to: to);
  final previous = ledger.sum(income: false, from: previousFrom, to: from);
  final categories = ledger.spentByCategory(from, to);
  final monthLength = daysInMonth(now);
  final daysLeft = (monthLength - now.day + 1).clamp(1, monthLength);
  final left = ledger.monthlyBudget - spent;
  final safe = left <= 0 ? 0.0 : left / daysLeft;
  String money(double value) => formatMoney(value, code);

  final advice = <Advice>[];

  if (ledger.entries.isEmpty) {
    advice.add(
      const Advice(
        tone: AdviceTone.watch,
        title: 'Nothing to read yet',
        body: 'Set your balance, then add an expense and a credit. Recommendations start as soon as there is activity.',
      ),
    );
  }

  if (left < 0) {
    advice.add(
      Advice(
        tone: AdviceTone.alert,
        title: 'Over this month’s budget',
        body:
            'You have spent ${money(spent)} against a ${money(ledger.monthlyBudget)} budget. Pause non-essential shopping until next month, or raise the budget in Settings if rent was included by mistake.',
      ),
    );
  } else if (spent > 0) {
    final pace = spent / now.day * monthLength;
    if (pace > ledger.monthlyBudget) {
      advice.add(
        Advice(
          tone: AdviceTone.watch,
          title: 'This pace overshoots the budget',
          body:
              'At today’s rate the month ends near ${money(pace)}. Keeping daily spending under ${money(safe)} leaves the budget intact.',
        ),
      );
    } else {
      advice.add(
        Advice(
          tone: AdviceTone.good,
          title: 'You can spend ${money(safe)} a day',
          body:
              '${money(left)} of the monthly budget is still free, spread over $daysLeft days. That is the number to stay under.',
        ),
      );
    }
  }

  final ranked = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  if (ranked.isNotEmpty && spent > 0) {
    final top = ranked.first;
    final share = (top.value / spent * 100).round();
    if (share >= 45) {
      advice.add(
        Advice(
          tone: AdviceTone.watch,
          title: '${top.key} is $share% of spending',
          body:
              '${money(top.value)} went to ${top.key.toLowerCase()}. One category that large usually has a bill you can renegotiate or a habit you can cap.',
        ),
      );
    }
  }

  for (final item in ranked) {
    final cap = ledger.budgets[item.key];
    if (cap == null || item.value <= cap) continue;
    advice.add(
      Advice(
        tone: AdviceTone.alert,
        title: '${item.key} is over its cap',
        body:
            '${money(item.value)} spent, cap is ${money(cap)}. Cut the next ${item.key.toLowerCase()} purchase or move the cap in line with what you actually need.',
      ),
    );
    break;
  }

  if (credit == 0 && spent > 0) {
    advice.add(
      const Advice(
        tone: AdviceTone.watch,
        title: 'No credit logged this month',
        body:
            'Salary, refunds, and transfers in are missing. Add them as credit so the balance and savings picture stay honest.',
      ),
    );
  } else if (credit > 0) {
    final saved = credit - spent;
    if (saved >= 0) {
      advice.add(
        Advice(
          tone: AdviceTone.good,
          title: 'Credits cover spending',
          body:
              '${money(credit)} came in and ${money(spent)} went out. ${money(saved)} is still unspent from this month’s credits.',
        ),
      );
    } else {
      advice.add(
        Advice(
          tone: AdviceTone.watch,
          title: 'Spending is ahead of credits',
          body:
              'Credits are ${money(credit)} and spending is ${money(spent)}. The gap is ${money(saved.abs())}, which is coming out of the balance you set.',
        ),
      );
    }
  }

  if (previous > 0 && spent > 0) {
    final percent = ((spent - previous) / previous * 100).round();
    if (percent <= -10) {
      advice.add(
        Advice(
          tone: AdviceTone.good,
          title: '${percent.abs()}% under last month',
          body: 'Last month was ${money(previous)}. Keep the same caps and this month finishes lighter.',
        ),
      );
    } else if (percent >= 15) {
      advice.add(
        Advice(
          tone: AdviceTone.watch,
          title: '$percent% above last month',
          body: 'Last month was ${money(previous)}. Look at the largest category before adding another discretionary expense.',
        ),
      );
    }
  }

  final repeats = <String, int>{};
  for (final entry in ledger.entries) {
    if (entry.amount >= 0) continue;
    if (entry.at.isBefore(from) || !entry.at.isBefore(to)) continue;
    repeats[entry.title] = (repeats[entry.title] ?? 0) + 1;
  }
  final habit = repeats.entries.where((item) => item.value >= 2).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (habit.isNotEmpty) {
    final name = habit.first.key;
    advice.add(
      Advice(
        tone: AdviceTone.watch,
        title: '$name shows up ${habit.first.value} times',
        body:
            'Repeated charges are where a weekly cap helps. Decide a limit before the next $name payment instead of reviewing it afterward.',
      ),
    );
  }

  if (ledger.balance < 0) {
    advice.add(
      Advice(
        tone: AdviceTone.alert,
        title: 'Balance is below zero',
        body:
            'The balance is ${money(ledger.balance)}. Update it in Settings if the opening number was wrong, or log the credit that should cover these expenses.',
      ),
    );
  }

  final summary = _summary(
    code: code,
    spent: spent,
    credit: credit,
    left: left,
    safe: safe,
    daysLeft: daysLeft,
    budget: ledger.monthlyBudget,
  );

  return SpendBrief(
    summary: summary,
    spent: spent,
    credit: credit,
    leftInBudget: left,
    safePerDay: safe,
    advice: advice.take(5).toList(),
  );
}

String _summary({
  required String code,
  required double spent,
  required double credit,
  required double left,
  required double safe,
  required int daysLeft,
  required double budget,
}) {
  String money(double value) => formatMoney(value, code);
  if (spent == 0 && credit == 0) {
    return 'Set your currency and balance, then add expenses and credits. Ajuga reads only what you log on this phone.';
  }
  if (left < 0) {
    return 'You are ${money(left.abs())} past the ${money(budget)} budget. New spending should wait, unless it is a bill you already planned.';
  }
  return 'Spent ${money(spent)} of ${money(budget)}. ${money(safe)} a day for the next $daysLeft days keeps you inside the budget. Credits this month: ${money(credit)}.';
}
