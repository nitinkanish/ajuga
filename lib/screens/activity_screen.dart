import 'package:flutter/material.dart';

import '../scope.dart';
import '../widgets/app_header.dart';
import '../widgets/transaction_list.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

enum _ActivityFilter { all, expenses, credits }

class _ActivityScreenState extends State<ActivityScreen> {
  final _search = TextEditingController();
  String _query = '';
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ExpenseScope.of(context);
    final entries = ledger.entriesFor(query: _query).where((entry) {
      if (_filter == _ActivityFilter.expenses) return entry.amount < 0;
      if (_filter == _ActivityFilter.credits) return entry.amount > 0;
      return true;
    }).toList();

    return AppPage(
      header: PageHeader(
        title: 'Activity',
        onBack: () => Navigator.pop(context),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Search merchants or categories',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF4F6FB),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _filter == _ActivityFilter.all,
                  onTap: () => setState(() => _filter = _ActivityFilter.all),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Expenses',
                  selected: _filter == _ActivityFilter.expenses,
                  onTap: () => setState(() => _filter = _ActivityFilter.expenses),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Credits',
                  selected: _filter == _ActivityFilter.credits,
                  onTap: () => setState(() => _filter = _ActivityFilter.credits),
                ),
              ],
            ),
          ),
          Expanded(child: TransactionList(entries: entries)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF121826) : const Color(0xFFF3F5FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF121826),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
