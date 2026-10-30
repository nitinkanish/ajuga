import 'package:flutter/material.dart';

import '../../theme.dart';
import '../../widgets/app_header.dart';
import '../../widgets/pressable.dart';

class LifeColors {
  LifeColors(this.dark);

  final bool dark;

  Color get sheet => dark ? const Color(0xFF10141C) : Colors.white;
  Color get ink => dark ? Colors.white : AppColors.ink;
  Color get muted => dark ? const Color(0xFFB7BECE) : AppColors.muted;
  Color get card => dark ? const Color(0xFF1A2130) : const Color(0xFFF6F7FB);
  Color get line => dark ? const Color(0xFF2A3344) : AppColors.line;

  static LifeColors of(BuildContext context) {
    return LifeColors(MediaQuery.platformBrightnessOf(context) == Brightness.dark);
  }
}

class LifePage extends StatelessWidget {
  const LifePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    return AppPage(
      background: colors.sheet,
      header: PageHeader(
        title: title,
        subtitle: subtitle,
        onBack: () => Navigator.pop(context),
      ),
      body: child,
    );
  }
}

class LifeButton extends StatelessWidget {
  const LifeButton({super.key, required this.label, required this.onTap, this.filled = true});

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    final background = filled ? (colors.dark ? Colors.white : AppColors.ink) : Colors.transparent;
    final foreground = filled ? (colors.dark ? AppColors.ink : Colors.white) : colors.ink;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: filled ? background : colors.line),
        ),
        child: Text(label, style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class LifeCard extends StatelessWidget {
  const LifeCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = LifeColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.line),
      ),
      child: child,
    );
  }
}
