import 'package:flutter/material.dart';

import '../category_style.dart';
import '../ledger.dart';
import '../scope.dart';
import '../theme.dart';
import 'pressable.dart';

class TransactionList extends StatelessWidget {
  const TransactionList({
    super.key,
    required this.entries,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 12),
  });

  final List<Entry> entries;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No transactions',
          style: TextStyle(color: AppColors.muted, fontSize: 15),
        ),
      );
    }

    final groups = groupEntries(entries);
    return ListView.builder(
      padding: padding,
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: index == 0 ? 2 : 18, bottom: 6),
              child: Text(
                group.label,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            for (final entry in group.items) TransactionRow(entry: entry),
          ],
        );
      },
    );
  }
}

class TransactionRow extends StatelessWidget {
  const TransactionRow({super.key, required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final style = styleFor(entry.category);
    final initials = initialsFor(entry.category, entry.title);
    final incoming = entry.amount >= 0;
    final code = ExpenseScope.of(context).currencyCode;

    return Pressable(
      onTap: () => showEntryDetail(context, entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: style.background,
                shape: BoxShape.circle,
              ),
              child: initials != null
                  ? Text(
                      initials,
                      style: TextStyle(
                        color: style.foreground,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Icon(style.icon, color: style.foreground, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatMoney(entry.amount, code, absolute: true),
                  style: TextStyle(
                    color: incoming ? AppColors.positive : AppColors.ink,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (entry.secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.secondary!,
                    style: const TextStyle(
                      color: AppColors.positive,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (entry.method.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.method,
                    style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void showEntryDetail(BuildContext context, Entry entry) {
  final ledger = ExpenseScope.of(context);
  final code = ledger.currencyCode;
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      final incoming = entry.amount >= 0;
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.paddingOf(context).bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: _Grabber()),
            const SizedBox(height: 18),
            Text(
              entry.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.4),
            ),
            const SizedBox(height: 6),
            Text(
              entry.subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 18),
            Text(
              formatMoney(entry.amount, code, absolute: true),
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.8,
                color: incoming ? AppColors.positive : AppColors.ink,
              ),
            ),
            const SizedBox(height: 18),
            _DetailLine(label: 'Category', value: entry.category),
            _DetailLine(label: 'Currency', value: code),
            if (entry.method.isNotEmpty) _DetailLine(label: 'Paid with', value: entry.method),
            _DetailLine(
              label: 'When',
              value: '${dayLabel(entry.at)} · ${entry.at.hour.toString().padLeft(2, '0')}:${entry.at.minute.toString().padLeft(2, '0')}',
            ),
            const SizedBox(height: 18),
            Pressable(
              onTap: () {
                ledger.deleteEntry(entry.id);
                Navigator.pop(context);
              },
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Remove transaction',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 4,
      decoration: BoxDecoration(
        color: const Color(0xFFE1E4EC),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

void showNotices(BuildContext context) {
  final ledger = ExpenseScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return ListenableBuilder(
        listenable: ledger,
        builder: (context, child) {
          return Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.paddingOf(context).bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _Grabber()),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    if (ledger.unread > 0)
                      Pressable(
                        onTap: ledger.markAllRead,
                        child: const Text(
                          'Mark read',
                          style: TextStyle(
                            color: Color(0xFF2457D6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final notice in ledger.notices)
                  Pressable(
                    onTap: () => ledger.markRead(notice),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: notice.read ? const Color(0xFFE1E4EC) : AppColors.positive,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  notice.title,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  notice.body,
                                  style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

void showAbout(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.paddingOf(context).bottom + 24),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _Grabber()),
            SizedBox(height: 18),
            Text('Ajuga', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 8),
            Text(
              'A calm place for balances, spending, and the transfers between them.',
              style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.4),
            ),
          ],
        ),
      );
    },
  );
}
