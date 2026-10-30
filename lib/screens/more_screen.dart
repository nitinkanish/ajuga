import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ledger.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/logo_mark.dart';
import '../widgets/pressable.dart';
import 'activity_screen.dart';
import 'lifeos/lifeos_screen.dart';
import 'advisor_screen.dart';
import 'insights_screen.dart';
import 'motion/daily_activity_screen.dart';
import 'motion/outdoor_hub_screen.dart';
import 'thermal_screen.dart';
import 'settings_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key, required this.onOpenCard, required this.onSignOut});

  final VoidCallback onOpenCard;
  final VoidCallback onSignOut;

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatus,
      child: Column(
        children: [
          PageHeader(
            brand: true,
            title: 'More',
            below: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullMonths[now.month - 1],
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  formatMoney(spent, code),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Spent · ${monthDelta(spent, previous)}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: RoundedSheetBody(
              child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                if (ranked.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F7FB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        for (final item in ranked.take(3))
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(item.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                Text(
                                  formatMoney(item.value, code),
                                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                _Row(
                  icon: Icons.auto_awesome_mosaic_rounded,
                  title: 'LifeOS',
                  subtitle: 'Today’s routine, energy, and weekly review',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => const LifeOsScreen()),
                  ),
                ),
                _Row(
                  icon: Icons.tune_rounded,
                  title: 'Currency and balance',
                  subtitle: '${ledger.currency.name} · ${formatMoney(ledger.balance, code)}',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => const SettingsScreen()),
                  ),
                ),
                _Row(
                  icon: Icons.directions_walk_rounded,
                  title: 'Daily activity',
                  subtitle: 'Steps, distance, and mobility from this iPhone',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const DailyActivityScreen(),
                    ),
                  ),
                ),
                _Row(
                  icon: Icons.device_thermostat_rounded,
                  title: 'Phone heat',
                  subtitle: 'Thermal level and a log from this iPhone',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => const ThermalScreen()),
                  ),
                ),
                _Row(
                  icon: Icons.terrain_rounded,
                  title: 'Outdoor tracking',
                  subtitle: 'Walk, run, and hike with GPS routes',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(
                      builder: (_) => const OutdoorHubScreen(),
                    ),
                  ),
                ),
                _Row(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Ajuga AI',
                  subtitle: 'What to change in this month’s spending',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => const AdvisorScreen()),
                  ),
                ),
                _Row(
                  icon: Icons.insights_rounded,
                  title: 'Insights',
                  subtitle: 'Categories, budgets, and last month',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => const InsightsScreen()),
                  ),
                ),
                _Row(
                  icon: Icons.receipt_long_rounded,
                  title: 'Activity',
                  subtitle: 'Expenses and credits',
                  onTap: () => Navigator.of(context).push(
                    CupertinoPageRoute<void>(builder: (_) => const ActivityScreen()),
                  ),
                ),
                _Row(
                  icon: Icons.credit_card_rounded,
                  title: 'Linked card',
                  subtitle: 'Ajuga Debit · 8152',
                  onTap: onOpenCard,
                ),
                _Row(
                  icon: Icons.refresh_rounded,
                  title: 'Restore sample data',
                  subtitle: 'Put the demo balances back',
                  onTap: () {
                    ledger.reset();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sample activity restored')),
                    );
                  },
                ),
                _Row(
                  icon: Icons.logout_rounded,
                  title: 'Back to welcome',
                  subtitle: 'Your activity stays on this phone',
                  onTap: onSignOut,
                ),
                const SizedBox(height: 18),
                const Row(
                  children: [
                    LogoMark(size: 22),
                    SizedBox(width: 8),
                    Text('Ajuga', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFF3F5FA),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: AppColors.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
