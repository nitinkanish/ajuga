import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ledger.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/app_header.dart';
import '../widgets/pressable.dart';

enum ComposerKind { expense, income, send }

class ComposerScreen extends StatefulWidget {
  const ComposerScreen({super.key, required this.kind});

  final ComposerKind kind;

  @override
  State<ComposerScreen> createState() => _ComposerScreenState();
}

class _ComposerScreenState extends State<ComposerScreen> {
  final _amount = TextEditingController();
  final _title = TextEditingController();
  final _note = TextEditingController();
  String _category = 'Food';
  String _method = 'Debit card';

  @override
  void dispose() {
    _amount.dispose();
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  String get _heading {
    switch (widget.kind) {
      case ComposerKind.expense:
        return 'Add expense';
      case ComposerKind.income:
        return 'Add credit';
      case ComposerKind.send:
        return 'Send';
    }
  }

  String get _titleHint {
    switch (widget.kind) {
      case ComposerKind.expense:
        return 'Merchant';
      case ComposerKind.income:
        return 'From';
      case ComposerKind.send:
        return 'Recipient';
    }
  }

  void _save() {
    final ledger = ExpenseScope.of(context);
    final amount = double.tryParse(_amount.text.trim());
    final title = _title.text.trim();
    if (amount == null || amount <= 0) {
      _toast('Enter an amount');
      return;
    }
    if (title.isEmpty) {
      _toast('Add a ${_titleHint.toLowerCase()}');
      return;
    }
    final outgoing = widget.kind != ComposerKind.income;

    final category = switch (widget.kind) {
      ComposerKind.expense => _category,
      ComposerKind.income => 'Income',
      ComposerKind.send => 'Transfers',
    };
    final note = _note.text.trim();
    ledger.addEntry(
      Entry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        walletCode: ledger.currencyCode,
        title: title,
        subtitle: note.isEmpty ? category : note,
        category: category,
        amount: outgoing ? -roundMoney(amount) : roundMoney(amount),
        at: DateTime.now(),
        method: _method,
      ),
    );
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ExpenseScope.of(context);
    return AppPage(
      resizeToAvoidBottomInset: true,
      header: PageHeader(
        title: _heading,
        onBack: () => Navigator.pop(context),
        backIcon: Icons.close_rounded,
        trailing: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              ledger.currencyCode,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
        ],
        below: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                prefixText: ledger.currency.symbol,
                prefixStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
                hintText: '0.00',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              ),
            ),
            Text(
              '${formatMoney(ledger.balance, ledger.currencyCode)} available',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                children: [
                  _Field(controller: _title, hint: _titleHint),
                  const SizedBox(height: 12),
                  _Field(controller: _note, hint: 'Note'),
                  if (widget.kind == ComposerKind.expense) ...[
                    const SizedBox(height: 18),
                    const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in expenseCategories)
                          _Choice(
                            label: category,
                            selected: _category == category,
                            onTap: () => setState(() => _category = category),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  const Text('Paid with', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final method in payMethods)
                        _Choice(
                          label: method,
                          selected: _method == method,
                          onTap: () => setState(() => _method = method),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.paddingOf(context).bottom + 12),
              child: PillButton(label: 'Save', onTap: _save),
            ),
          ],
        ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
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

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : const Color(0xFFF3F5FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}
