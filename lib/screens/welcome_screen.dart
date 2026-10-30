import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import '../widgets/backdrop.dart';
import '../widgets/logo_mark.dart';
import '../widgets/pressable.dart';
import '../widgets/transaction_list.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onEnter});

  final VoidCallback onEnter;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightStatus,
      child: Scaffold(
        body: FintechBackdrop(
          tone: BackdropTone.welcome,
          expand: true,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Pressable(
                    onTap: () => showAbout(context),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.menu_rounded, color: AppColors.ink, size: 26),
                    ),
                  ),
                  const Spacer(flex: 5),
                  const Center(child: LogoMark(size: 96)),
                  const Spacer(flex: 4),
                  const Text(
                    "TOMORROW'S\nBUDGET IS HERE",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      height: 1.02,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Experience spending reimagined for the digital age — secure, intuitive, and built for the way you live today.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PillButton(label: 'Start Tracking', light: true, onTap: onEnter),
                  const SizedBox(height: 6),
                  Pressable(
                    onTap: onEnter,
                    child: const SizedBox(
                      height: 44,
                      width: double.infinity,
                      child: Center(
                        child: Text(
                          'I Already Track',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
