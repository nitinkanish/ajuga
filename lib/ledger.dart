import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _storeKey = 'aster.ledger.v2';

const shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const fullMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const expenseCategories = [
  'Groceries',
  'Food',
  'Taxi',
  'Shopping',
  'Bills',
  'Health',
  'Transfers',
  'Other',
];

const payMethods = ['UPI', 'Debit card', 'Credit card', 'Cash'];

const defaultCategoryBudgets = <String, double>{
  'Groceries': 8000,
  'Food': 6000,
  'Taxi': 4000,
  'Shopping': 7000,
  'Bills': 22000,
  'Transfers': 5000,
  'Health': 3000,
};

class CurrencyOption {
  const CurrencyOption(this.code, this.symbol, this.name, this.flag);

  final String code;
  final String symbol;
  final String name;
  final String flag;
}

const currencies = <CurrencyOption>[
  CurrencyOption('INR', '₹', 'Indian Rupee', '🇮🇳'),
  CurrencyOption('USD', '\$', 'US Dollar', '🇺🇸'),
  CurrencyOption('EUR', '€', 'Euro', '🇪🇺'),
  CurrencyOption('GBP', '£', 'British Pound', '🇬🇧'),
  CurrencyOption('AED', 'AED ', 'UAE Dirham', '🇦🇪'),
  CurrencyOption('SGD', 'S\$', 'Singapore Dollar', '🇸🇬'),
  CurrencyOption('AUD', 'A\$', 'Australian Dollar', '🇦🇺'),
  CurrencyOption('CAD', 'C\$', 'Canadian Dollar', '🇨🇦'),
];

CurrencyOption currencyByCode(String code) {
  return currencies.firstWhere(
    (item) => item.code == code,
    orElse: () => currencies.first,
  );
}

class Entry {
  Entry({
    required this.id,
    required this.walletCode,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.amount,
    required this.at,
    this.method = '',
    this.secondary,
  });

  final String id;
  final String walletCode;
  final String title;
  final String subtitle;
  final String category;
  final double amount;
  final DateTime at;
  final String method;
  final String? secondary;

  Map<String, dynamic> toJson() => {
    'id': id,
    'wallet': walletCode,
    'title': title,
    'subtitle': subtitle,
    'category': category,
    'amount': amount,
    'at': at.toIso8601String(),
    'method': method,
    'secondary': secondary,
  };

  factory Entry.fromJson(Map<String, dynamic> json) {
    return Entry(
      id: json['id'] as String,
      walletCode: json['wallet'] as String? ?? 'INR',
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      at: DateTime.parse(json['at'] as String),
      method: json['method'] as String? ?? '',
      secondary: json['secondary'] as String?,
    );
  }
}

class Notice {
  Notice(this.title, this.body);

  final String title;
  final String body;
  bool read = false;
}

class EntryGroup {
  const EntryGroup(this.label, this.items);

  final String label;
  final List<Entry> items;
}

class Ledger extends ChangeNotifier {
  Ledger() {
    _seed();
  }

  String currencyCode = 'INR';
  double balance = 84250;
  double monthlyBudget = 50000;
  Map<String, double> budgets = Map<String, double>.of(defaultCategoryBudgets);
  List<Entry> entries = [];
  final List<Notice> notices = [
    Notice('Food budget', 'Food spending is approaching this month’s budget.'),
    Notice('Swiggy receipt', 'A UPI payment to Swiggy posted today.'),
    Notice('Salary credited', 'October salary is in your balance.'),
  ];

  bool _dirty = false;

  int get unread => notices.where((notice) => !notice.read).length;

  CurrencyOption get currency => currencyByCode(currencyCode);

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_dirty) return;
      final raw = prefs.getString(_storeKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      currencyCode = map['currency'] as String? ?? 'INR';
      balance = (map['balance'] as num?)?.toDouble() ?? balance;
      monthlyBudget = (map['budget'] as num?)?.toDouble() ?? monthlyBudget;
      final storedBudgets = map['budgets'];
      if (storedBudgets is Map) {
        budgets = storedBudgets.map(
          (key, value) => MapEntry(key.toString(), (value as num).toDouble()),
        );
      }
      entries = (map['entries'] as List)
          .map((item) => Entry.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
      if (!_dirty) notifyListeners();
    } catch (_) {}
  }

  void setCurrency(String code) {
    if (currencyCode == code) return;
    currencyCode = code;
    _touch();
  }

  void setBalance(double value) {
    balance = roundMoney(value);
    _touch();
  }

  void setMonthlyBudget(double value) {
    monthlyBudget = roundMoney(value);
    _touch();
  }

  void markAllRead() {
    for (final notice in notices) {
      notice.read = true;
    }
    notifyListeners();
  }

  void markRead(Notice notice) {
    notice.read = true;
    notifyListeners();
  }

  void addEntry(Entry entry) {
    entries.insert(0, entry);
    balance = roundMoney(balance + entry.amount);
    _touch();
  }

  void deleteEntry(String id) {
    final index = entries.indexWhere((entry) => entry.id == id);
    if (index < 0) return;
    final entry = entries.removeAt(index);
    balance = roundMoney(balance - entry.amount);
    _touch();
  }

  void reset() {
    _seed();
    _touch();
  }

  List<Entry> entriesFor({String query = ''}) {
    final needle = query.trim().toLowerCase();
    final list = entries.where((entry) {
      if (needle.isEmpty) return true;
      return entry.title.toLowerCase().contains(needle) ||
          entry.subtitle.toLowerCase().contains(needle) ||
          entry.category.toLowerCase().contains(needle);
    }).toList();
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  double sum({
    required bool income,
    DateTime? from,
    DateTime? to,
    String? method,
    String? category,
  }) {
    var total = 0.0;
    for (final entry in entries) {
      if (income && entry.amount < 0) continue;
      if (!income && entry.amount >= 0) continue;
      if (from != null && entry.at.isBefore(from)) continue;
      if (to != null && !entry.at.isBefore(to)) continue;
      if (method != null && entry.method != method) continue;
      if (category != null && entry.category != category) continue;
      total += entry.amount.abs();
    }
    return total;
  }

  Map<String, double> spentByCategory(DateTime from, DateTime to) {
    final totals = <String, double>{};
    for (final entry in entries) {
      if (entry.amount >= 0) continue;
      if (entry.at.isBefore(from) || !entry.at.isBefore(to)) continue;
      if (entry.category == 'Conversion' || entry.category == 'Income') continue;
      totals[entry.category] = (totals[entry.category] ?? 0) + entry.amount.abs();
    }
    return totals;
  }

  void _touch() {
    _dirty = true;
    notifyListeners();
    unawaited(_persist());
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storeKey,
        jsonEncode({
          'currency': currencyCode,
          'balance': balance,
          'budget': monthlyBudget,
          'budgets': budgets,
          'entries': entries.map((entry) => entry.toJson()).toList(),
        }),
      );
    } catch (_) {}
  }

  void _seed() {
    final now = DateTime.now();
    DateTime at(int days, int hour, int minute) {
      final day = now.subtract(Duration(days: days));
      return DateTime(day.year, day.month, day.day, hour, minute);
    }

    currencyCode = 'INR';
    balance = 84250;
    monthlyBudget = 50000;
    budgets = Map<String, double>.of(defaultCategoryBudgets);
    entries = [
      Entry(
        id: 's1',
        walletCode: 'INR',
        title: 'Swiggy',
        subtitle: 'Food delivery',
        category: 'Food',
        amount: -486,
        at: at(0, 13, 20),
        method: 'UPI',
      ),
      Entry(
        id: 's2',
        walletCode: 'INR',
        title: 'Uber',
        subtitle: 'Taxi',
        category: 'Taxi',
        amount: -214,
        at: at(0, 9, 5),
        method: 'UPI',
      ),
      Entry(
        id: 's3',
        walletCode: 'INR',
        title: 'Priya Sharma',
        subtitle: 'Transfers',
        category: 'Transfers',
        amount: -1500,
        at: at(0, 8, 12),
        method: 'UPI',
      ),
      Entry(
        id: 's4',
        walletCode: 'INR',
        title: 'BigBasket',
        subtitle: 'Grocery Shop',
        category: 'Groceries',
        amount: -1284,
        at: at(1, 18, 40),
        method: 'UPI',
      ),
      Entry(
        id: 's5',
        walletCode: 'INR',
        title: 'Zomato',
        subtitle: 'Food delivery',
        category: 'Food',
        amount: -640,
        at: at(1, 20, 15),
        method: 'Debit card',
      ),
      Entry(
        id: 's6',
        walletCode: 'INR',
        title: 'Airtel',
        subtitle: 'Mobile bill',
        category: 'Bills',
        amount: -599,
        at: at(3, 7, 0),
        method: 'UPI',
      ),
      Entry(
        id: 's7',
        walletCode: 'INR',
        title: 'Amazon',
        subtitle: 'Shopping',
        category: 'Shopping',
        amount: -2499,
        at: at(5, 16, 10),
        method: 'Credit card',
      ),
      Entry(
        id: 's8',
        walletCode: 'INR',
        title: 'Netflix',
        subtitle: 'Subscription',
        category: 'Bills',
        amount: -649,
        at: at(6, 6, 0),
        method: 'Debit card',
      ),
      Entry(
        id: 's9',
        walletCode: 'INR',
        title: 'Salary',
        subtitle: 'October payroll',
        category: 'Income',
        amount: 72000,
        at: at(8, 9, 30),
        method: 'Bank transfer',
      ),
      Entry(
        id: 's10',
        walletCode: 'INR',
        title: 'House rent',
        subtitle: 'Monthly rent',
        category: 'Bills',
        amount: -18000,
        at: at(9, 10, 0),
        method: 'UPI',
      ),
      Entry(
        id: 's11',
        walletCode: 'INR',
        title: 'Apollo Pharmacy',
        subtitle: 'Medicines',
        category: 'Health',
        amount: -430,
        at: at(11, 17, 45),
        method: 'UPI',
      ),
      Entry(
        id: 's12',
        walletCode: 'INR',
        title: 'Zomato',
        subtitle: 'Dinner',
        category: 'Food',
        amount: -890,
        at: at(34, 21, 10),
        method: 'UPI',
      ),
      Entry(
        id: 's13',
        walletCode: 'INR',
        title: 'BigBasket',
        subtitle: 'Grocery Shop',
        category: 'Groceries',
        amount: -2140,
        at: at(36, 12, 0),
        method: 'UPI',
      ),
      Entry(
        id: 's14',
        walletCode: 'INR',
        title: 'Amazon',
        subtitle: 'Shopping',
        category: 'Shopping',
        amount: -1890,
        at: at(40, 15, 20),
        method: 'Credit card',
      ),
    ];
  }
}

double roundMoney(double value) => (value * 100).round() / 100.0;

String formatMoney(
  double value,
  String code, {
  bool symbol = true,
  bool absolute = false,
}) {
  final option = currencyByCode(code);
  final signed = absolute ? value.abs() : value;
  final negative = signed < 0;
  final fixed = signed.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final body =
      '${symbol ? option.symbol : ''}${_groupDigits(parts[0], indian: code == 'INR')}.${parts[1]}';
  return negative ? '-$body' : body;
}

String _groupDigits(String digits, {required bool indian}) {
  if (digits.length <= 3) return digits;
  if (!indian) {
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    return grouped.toString();
  }
  final head = digits.substring(0, digits.length - 3);
  final tail = digits.substring(digits.length - 3);
  final chunks = <String>[];
  var rest = head;
  while (rest.length > 2) {
    chunks.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) chunks.insert(0, rest);
  return '${chunks.join(',')},$tail';
}

String dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  final month = shortMonths[date.month - 1];
  if (date.year == now.year) return '$month ${date.day}';
  return '$month ${date.day}, ${date.year}';
}

List<EntryGroup> groupEntries(List<Entry> items) {
  final groups = <String, List<Entry>>{};
  final order = <String>[];
  for (final entry in items) {
    final label = dayLabel(entry.at);
    if (!groups.containsKey(label)) {
      groups[label] = [];
      order.add(label);
    }
    groups[label]!.add(entry);
  }
  return [for (final label in order) EntryGroup(label, groups[label]!)];
}

DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month);

DateTime startOfNextMonth(DateTime date) => DateTime(date.year, date.month + 1);

int daysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;

String monthDelta(double current, double previous) {
  if (previous <= 0 && current <= 0) return 'No spending yet';
  if (previous <= 0) return 'First month of spending';
  final percent = ((current - previous) / previous * 100).round();
  if (percent == 0) return 'Level with last month';
  if (percent < 0) return '${percent.abs()}% under last month';
  return '$percent% over last month';
}
