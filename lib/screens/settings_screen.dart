import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ledger.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/pressable.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? _balance;
  TextEditingController? _budget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_balance != null) return;
    final ledger = ExpenseScope.of(context);
    _balance = TextEditingController(text: ledger.balance.toStringAsFixed(2));
    _budget = TextEditingController(text: ledger.monthlyBudget.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _balance?.dispose();
    _budget?.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _saveBalance(Ledger ledger) {
    final value = double.tryParse(_balance?.text.trim() ?? '');
    if (value == null) {
      _toast('Enter the balance as a number');
      return;
    }
    ledger.setBalance(value);
    HapticFeedback.mediumImpact();
    _toast('Balance updated');
  }

  void _saveBudget(Ledger ledger) {
    final value = double.tryParse(_budget?.text.trim() ?? '');
    if (value == null || value < 0) {
      _toast('Enter a monthly budget');
      return;
    }
    ledger.setMonthlyBudget(value);
    HapticFeedback.mediumImpact();
    _toast('Budget updated');
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ExpenseScope.of(context);

    return AppPage(
      header: PageHeader(
        title: 'Settings',
        subtitle: 'Currency, the balance you have now, and the monthly budget Ajuga watches.',
        onBack: () => Navigator.pop(context),
      ),
      body: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  const _Label('Currency'),
                  const SizedBox(height: 8),
                  for (final option in currencies)
                    Pressable(
                      onTap: () {
                        ledger.setCurrency(option.code);
                        HapticFeedback.selectionClick();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Text(option.flag, style: const TextStyle(fontSize: 22)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(option.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    '${option.code} · ${option.symbol}1,000',
                                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                            if (ledger.currencyCode == option.code)
                              const Icon(Icons.check_rounded, color: Color(0xFF2457D6)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  const _Label('Current balance'),
                  const SizedBox(height: 6),
                  const Text(
                    'This is the money you have today. Saving it replaces the number on home. It does not create a transaction.',
                    style: TextStyle(color: AppColors.muted, height: 1.35, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  _AmountField(controller: _balance!, prefix: ledger.currency.symbol),
                  const SizedBox(height: 10),
                  PillButton(label: 'Save balance', onTap: () => _saveBalance(ledger)),
                  const SizedBox(height: 22),
                  const _Label('Monthly budget'),
                  const SizedBox(height: 6),
                  const Text(
                    'Ajuga uses this to tell you what is safe to spend for the rest of the month.',
                    style: TextStyle(color: AppColors.muted, height: 1.35, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  _AmountField(controller: _budget!, prefix: ledger.currency.symbol),
                  const SizedBox(height: 10),
                  PillButton(label: 'Save budget', onTap: () => _saveBudget(ledger)),
                ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700));
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({required this.controller, required this.prefix});

  final TextEditingController controller;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        prefixText: prefix,
        filled: true,
        fillColor: const Color(0xFFF4F6FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
