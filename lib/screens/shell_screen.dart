import 'package:flutter/material.dart';

import '../theme.dart';
import '../thermal/heat_monitor.dart';
import '../widgets/logo_mark.dart';
import '../widgets/pressable.dart';
import 'card_screen.dart';
import 'home_screen.dart';
import 'more_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    HeatMonitor.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(onOpenCard: () => setState(() => _index = 1)),
          const CardScreen(),
          MoreScreen(
            onOpenCard: () => setState(() => _index = 1),
            onSignOut: widget.onSignOut,
          ),
        ],
      ),
      bottomNavigationBar: _NavBar(
        index: _index,
        onChanged: (index) => setState(() => _index = index),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavButton(
                selected: index == 0,
                onTap: () => onChanged(0),
                child: const Icon(Icons.home_rounded, size: 26),
              ),
              _NavButton(
                selected: index == 1,
                onTap: () => onChanged(1),
                child: const LogoMark(size: 28),
              ),
              _NavButton(
                selected: index == 2,
                onTap: () => onChanged(2),
                child: const Icon(Icons.more_horiz_rounded, size: 28),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        height: 44,
        child: Center(
          child: IconTheme(
            data: IconThemeData(
              color: AppColors.ink.withValues(alpha: selected ? 1 : 0.32),
            ),
            child: Opacity(opacity: selected ? 1 : 0.38, child: child),
          ),
        ),
      ),
    );
  }
}
