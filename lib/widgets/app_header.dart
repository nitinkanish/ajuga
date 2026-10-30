import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'backdrop.dart';
import 'logo_mark.dart';
import 'pressable.dart';

class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.dot = false,
    this.light = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool dot;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final background = light ? const Color(0xFFF2F4F8) : Colors.white.withValues(alpha: 0.16);
    final foreground = light ? AppColors.ink : Colors.white;
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: background, shape: BoxShape.circle),
                child: Icon(icon, color: foreground, size: 20),
              ),
              if (dot)
                const Positioned(
                  top: 2,
                  right: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF3DDC97), shape: BoxShape.circle),
                    child: SizedBox(width: 8, height: 8),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    this.title,
    this.subtitle,
    this.onBack,
    this.backIcon = Icons.arrow_back_ios_new_rounded,
    this.trailing = const <Widget>[],
    this.below,
    this.brand = false,
  });

  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final IconData backIcon;
  final List<Widget> trailing;
  final Widget? below;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final caption = subtitle?.trim() ?? '';
    return FintechBackdrop(
      tone: BackdropTone.night,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, top + 6, 12, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  if (onBack != null) ...[
                    HeaderIconButton(icon: backIcon, onTap: onBack!),
                    const SizedBox(width: 8),
                  ] else if (brand) ...[
                    const LogoMark(size: 32),
                    const SizedBox(width: 10),
                  ],
                  if (title != null)
                    Expanded(
                      child: Text(
                        title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  ...trailing,
                ],
              ),
            ),
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                caption,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.74),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
            if (below != null) ...[
              const SizedBox(height: 12),
              below!,
            ],
          ],
        ),
      ),
    );
  }
}

class RoundedSheetBody extends StatelessWidget {
  const RoundedSheetBody({super.key, required this.child, this.color = Colors.white});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -20,
          left: 0,
          right: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: ColoredBox(
              color: color,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.header,
    required this.body,
    this.background = Colors.white,
    this.resizeToAvoidBottomInset = false,
  });

  final Widget header;
  final Widget body;
  final Color background;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatus,
      child: Scaffold(
        backgroundColor: AppColors.night,
        resizeToAvoidBottomInset: resizeToAvoidBottomInset,
        body: Column(
          children: [
            header,
            Expanded(child: RoundedSheetBody(color: background, child: body)),
          ],
        ),
      ),
    );
  }
}
