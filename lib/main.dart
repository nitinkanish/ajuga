import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ledger.dart';
import 'scope.dart';
import 'screens/shell_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';
import 'widgets/backdrop.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Grain.warm();
  runApp(const AjugaApp());
}

class AjugaApp extends StatefulWidget {
  const AjugaApp({super.key});

  @override
  State<AjugaApp> createState() => _AjugaAppState();
}

class _AjugaAppState extends State<AjugaApp> {
  final Ledger ledger = Ledger();
  bool _inside = false;

  @override
  void initState() {
    super.initState();
    ledger.load();
  }

  @override
  void dispose() {
    ledger.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExpenseScope(
      notifier: ledger,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Ajuga',
        theme: buildAjugaTheme(),
        home: _inside
            ? ShellScreen(onSignOut: () => setState(() => _inside = false))
            : WelcomeScreen(onEnter: () => setState(() => _inside = true)),
      ),
    );
  }
}
