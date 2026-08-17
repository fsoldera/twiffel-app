import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Full-width pill CTA pinned above the bottom safe area.
class StickyPrimaryButton extends StatelessWidget {
  const StickyPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final colors = TwiffelColors.of(context);

    return Material(
      color: colors.pageBg,
      elevation: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TwiffelTokens.buttonHeight / 2),
              boxShadow: enabled
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
              onPressed: enabled ? onPressed : null,
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: TwiffelTokens.textOnPrimary,
                      ),
                    )
                  : Text(label),
            ),
          ),
        ),
      ),
    );
  }
}
