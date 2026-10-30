import 'package:flutter/material.dart';

import 'ledger.dart';

class ExpenseScope extends InheritedNotifier<Ledger> {
  const ExpenseScope({
    super.key,
    required Ledger super.notifier,
    required super.child,
  });

  static Ledger of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ExpenseScope>();
    assert(scope != null, 'ExpenseScope missing');
    return scope!.notifier!;
  }
}
