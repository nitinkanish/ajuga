import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ledger.dart';
import '../scope.dart';
import '../theme.dart';
import '../widgets/backdrop.dart';
import '../widgets/logo_mark.dart';
import '../widgets/pressable.dart';

class CardScreen extends StatefulWidget {
  const CardScreen({super.key});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  bool _revealed = true;

  @override
  Widget build(BuildContext context) {
    final ledger = ExpenseScope.of(context);
    final code = ledger.currencyCode;
    final now = DateTime.now();
    final spent = ledger.sum(
      income: false,
      from: startOfMonth(now),
      to: startOfNextMonth(now),
      method: 'Debit card',
    );
    final top = MediaQuery.paddingOf(context).top;
    final cardHeight = (MediaQuery.sizeOf(context).height * 0.32).clamp(240.0, 310.0);
    const number = '5231 7252 1769 8152';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkStatus,
      child: FintechBackdrop(
        tone: BackdropTone.card,
        expand: true,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, top + 6, 16, 4),
              child: const SizedBox(
                height: 44,
                child: Row(
                  children: [
                    LogoMark(size: 32),
                    SizedBox(width: 10),
                    Text(
                      'Card',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: cardHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 68),
                child: _DebitCard(revealed: _revealed),
              ),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  children: [
                    Text(
                      formatMoney(ledger.balance, code),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${formatMoney(spent, code)} on this card in ${fullMonths[now.month - 1]}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Card info',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'Card number',
                      value: _revealed ? number : '•••• •••• •••• 8152',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Pressable(
                            onTap: () => setState(() => _revealed = !_revealed),
                            child: Icon(
                              _revealed ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              size: 18,
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Pressable(
                            onTap: () {
                              Clipboard.setData(const ClipboardData(text: number));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Card number copied')),
                              );
                            },
                            child: const Icon(Icons.copy_rounded, size: 18, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const _InfoRow(label: 'CVC', value: '678'),
                    const _InfoRow(label: 'Expiry date', value: '08/29'),
                    const SizedBox(height: 8),
                    const Text(
                      'Sample card for this demo. Nothing here is a live account.',
                      style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebitCard extends StatelessWidget {
  const _DebitCard({required this.revealed});

  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x590A1A4A), blurRadius: 28, offset: Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF8ECBFF),
                    Color(0xFF3A6DFF),
                    Color(0xFF152A6B),
                    Color(0xFF070C18),
                  ],
                  stops: [0, 0.28, 0.62, 1],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.8),
                  radius: 0.9,
                  colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                ),
              ),
            ),
            const GrainOverlay(opacity: 0.28),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Text(
                      revealed ? '8152' : '•••• 8152',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const LogoMark(size: 72),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.contactless_outlined, color: Colors.white.withValues(alpha: 0.8), size: 20),
                      const Spacer(),
                      const Text(
                        'Debit',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 15)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                letterSpacing: 0.2,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}
