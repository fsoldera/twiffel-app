import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Bottom bar with Previous (1/3) and Next/primary (2/3).
class StickyNavButtons extends StatelessWidget {
  const StickyNavButtons({
    super.key,
    required this.previousLabel,
    required this.nextLabel,
    required this.onPrevious,
    required this.onNext,
    this.nextLoading = false,
  });

  final String previousLabel;
  final String nextLabel;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool nextLoading;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final nextEnabled = onNext != null && !nextLoading;

    return Material(
      color: colors.pageBg,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton(
                  onPressed: onPrevious,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    foregroundColor: colors.textPrimary,
                    side: BorderSide(color: colors.borderDefault),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(previousLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: nextEnabled
                        ? const [
                            BoxShadow(
                              color: Color(0x24D97706),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: FilledButton(
                    onPressed: nextEnabled ? onNext : null,
                    child: nextLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: TwiffelTokens.textOnPrimary,
                            ),
                          )
                        : Text(nextLabel),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
