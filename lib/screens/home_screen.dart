import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ledger.dart';
import '../motion/activity_bridge.dart';
import '../motion/calculations.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/logo_mark.dart';
import '../widgets/pressable.dart';
import '../widgets/transaction_list.dart';
import 'activity_screen.dart';
import 'advisor_screen.dart';
import 'composer_screen.dart';
import 'insights_screen.dart';
import 'lifeos/lifeos_screen.dart';
import 'motion/daily_activity_screen.dart';
import 'motion/outdoor_hub_screen.dart';
import 'settings_screen.dart';
import 'thermal_screen.dart';
import '../thermal/heat_log.dart';
import '../thermal/heat_monitor.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenCard});

  final VoidCallback onOpenCard;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _search = TextEditingController();
  String _query = '';
  DailyActivitySnapshot? _movement;
  String _heat = 'unknown';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMovement();
    _loadHeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMovement();
      _loadHeat();
    }
  }

  Future<void> _loadHeat() async {
    final reading = await ThermalBridge.snapshot();
    if (!mounted) return;
    setState(() {
      _heat = reading.tempC != null ? '${reading.tempC!.toStringAsFixed(1)}°' : heatLabel(reading.state);
    });
  }

  Future<void> _loadMovement() async {
    try {
      final snapshot = await ActivityBridge.getDailyActivity();
      if (!mounted) return;
      setState(() => _movement = snapshot);
    } catch (_) {}
  }

  void _push(Widget screen) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ExpenseScope.of(context);
    final code = ledger.currencyCode;
    final entries = ledger.entriesFor(query: _query);
    final now = DateTime.now();
    final spent = ledger.sum(income: false, from: startOfMonth(now), to: startOfNextMonth(now));
    final left = ledger.monthlyBudget - spent;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatus,
      child: Column(
        children: [
          PageHeader(
            brand: true,
            title: 'Ajuga',
            trailing: [
              HeaderIconButton(
                icon: Icons.graphic_eq_rounded,
                onTap: () => _openAsk(ledger),
              ),
              HeaderIconButton(
                icon: Icons.notifications_none_rounded,
                dot: ledger.unread > 0,
                onTap: () => showNotices(context),
              ),
            ],
            below: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchField(
                  controller: _search,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: () {
                    _search.clear();
                    setState(() => _query = '');
                  },
                ),
                const SizedBox(height: 16),
                Pressable(
                  onTap: () => _push(const SettingsScreen()),
                  child: _CurrencyChip(currency: ledger.currency),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 240),
                    child: Text(
                      formatMoney(ledger.balance, code),
                      key: ValueKey('$code-${ledger.balance.toStringAsFixed(2)}'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.2,
                        height: 1.05,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  left >= 0
                      ? '${formatMoney(left, code)} left in ${fullMonths[now.month - 1]}'
                      : '${formatMoney(left.abs(), code)} over the ${fullMonths[now.month - 1]} budget',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniCard(onTap: widget.onOpenCard),
                    const SizedBox(width: 10),
                    _MiniCard(onTap: widget.onOpenCard),
                    const SizedBox(width: 10),
                    _MiniCard(add: true, onTap: widget.onOpenCard),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: RoundedSheetBody(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Row(
                      children: [
                        _ActionButton(
                          icon: Icons.add_rounded,
                          label: 'ADD',
                          onTap: () => _push(const ComposerScreen(kind: ComposerKind.expense)),
                        ),
                        const SizedBox(width: 10),
                        _ActionButton(
                          icon: Icons.south_west_rounded,
                          label: 'CREDIT',
                          onTap: () => _push(const ComposerScreen(kind: ComposerKind.income)),
                        ),
                        const SizedBox(width: 10),
                        _ActionButton(
                          icon: Icons.auto_awesome_rounded,
                          label: 'ADVISOR',
                          onTap: () => _push(const AdvisorScreen()),
                        ),
                        const SizedBox(width: 10),
                        _ActionButton(
                          icon: Icons.grid_view_rounded,
                          label: 'MORE',
                          onTap: () => _openMore(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: _FeatureCard(
                      icon: Icons.auto_awesome_mosaic_rounded,
                      title: 'LifeOS',
                      value: 'Today',
                      subtitle: 'Routine, energy, and one next step',
                      onTap: () => _push(const LifeOsScreen()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.directions_walk_rounded,
                            title: 'Daily activity',
                            value: _stepsLabel(_movement?.steps),
                            subtitle: _movement?.distanceMeters == null
                                ? 'Steps and distance'
                                : formatDistanceKm(_movement!.distanceMeters!),
                            onTap: () async {
                              await Navigator.of(context).push(
                                CupertinoPageRoute<void>(
                                  builder: (_) => const DailyActivityScreen(),
                                ),
                              );
                              _loadMovement();
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _FeatureCard(
                            icon: Icons.terrain_rounded,
                            title: 'Outdoor',
                            value: 'Track',
                            subtitle: 'Walk, run, hike',
                            onTap: () => _push(const OutdoorHubScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                    child: _FeatureCard(
                      icon: Icons.device_thermostat_rounded,
                      title: 'Phone heat',
                      value: heatLabel(_heat),
                      subtitle: 'Thermal log on this iPhone',
                      onTap: () async {
                        await Navigator.of(context).push(
                          CupertinoPageRoute<void>(builder: (_) => const ThermalScreen()),
                        );
                        _loadHeat();
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Row(
                      children: [
                        const Text(
                          'Transactions',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                        ),
                        const Spacer(),
                        Pressable(
                          onTap: () => _push(const ActivityScreen()),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                            child: Text(
                              'View all',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: TransactionList(entries: entries)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openAsk(Ledger ledger) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        void go(String query) {
          Navigator.pop(context);
          _search.text = query;
          setState(() => _query = query);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.paddingOf(context).bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ask Ajuga',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Jump to a slice of your spending.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(label: 'Food', onTap: () => go('Food')),
                  _Chip(label: 'Taxi', onTap: () => go('Taxi')),
                  _Chip(label: 'Groceries', onTap: () => go('Grocer')),
                  _Chip(
                    label: 'Add expense',
                    onTap: () {
                      Navigator.pop(context);
                      _push(const ComposerScreen(kind: ComposerKind.expense));
                    },
                  ),
                  _Chip(
                    label: 'Insights',
                    onTap: () {
                      Navigator.pop(context);
                      _push(const InsightsScreen());
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _openMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.paddingOf(context).bottom + 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetAction(
                icon: Icons.tune_rounded,
                label: 'Currency and balance',
                onTap: () {
                  Navigator.pop(context);
                  _push(const SettingsScreen());
                },
              ),
              _SheetAction(
                icon: Icons.directions_walk_rounded,
                label: 'Daily activity',
                onTap: () {
                  Navigator.pop(context);
                  _push(const DailyActivityScreen());
                },
              ),
              _SheetAction(
                icon: Icons.terrain_rounded,
                label: 'Outdoor tracking',
                onTap: () {
                  Navigator.pop(context);
                  _push(const OutdoorHubScreen());
                },
              ),
              _SheetAction(
                icon: Icons.auto_awesome_rounded,
                label: 'Ajuga AI',
                onTap: () {
                  Navigator.pop(context);
                  _push(const AdvisorScreen());
                },
              ),
              _SheetAction(
                icon: Icons.insights_rounded,
                label: 'Insights',
                onTap: () {
                  Navigator.pop(context);
                  _push(const InsightsScreen());
                },
              ),
              _SheetAction(
                icon: Icons.receipt_long_rounded,
                label: 'All activity',
                onTap: () {
                  Navigator.pop(context);
                  _push(const ActivityScreen());
                },
              ),
              _SheetAction(
                icon: Icons.credit_card_rounded,
                label: 'Linked card',
                onTap: () {
                  Navigator.pop(context);
                  widget.onOpenCard();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.7), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 15),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            Pressable(
              onTap: onClear,
              child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.7), size: 18),
            ),
        ],
      ),
    );
  }
}

String _stepsLabel(int? steps) {
  if (steps == null) return '—';
  final text = steps.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) grouped.write(',');
    grouped.write(text[i]);
  }
  return grouped.toString();
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2457D6)),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  const _CurrencyChip({required this.currency});

  final CurrencyOption currency;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(currency.flag, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currency.code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              currency.name,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(width: 4),
        Icon(Icons.expand_more_rounded, color: Colors.white.withValues(alpha: 0.8), size: 18),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.onTap, this.add = false});

  final VoidCallback onTap;
  final bool add;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 78,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: add
                ? const [Color(0xFF24345C), Color(0xFF152038)]
                : const [Color(0xFF1A2744), Color(0xFF0A1020)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: add
            ? const Icon(Icons.add_rounded, color: Colors.white, size: 22)
            : const LogoMark(size: 22),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Pressable(
        onTap: onTap,
        child: Container(
          height: 74,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
            boxShadow: const [
              BoxShadow(color: Color(0x0A0C1222), blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: AppColors.ink),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.ink),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
