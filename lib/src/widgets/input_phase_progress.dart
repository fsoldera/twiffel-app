import 'package:flutter/material.dart';

import '../pages/decision_copy.dart';
import '../theme/tokens.dart';

/// Sticky 3-step input progress, shown above the form nav buttons.
class InputPhaseProgress extends StatelessWidget {
  const InputPhaseProgress({
    super.key,
    required this.stepIndex,
    this.stepCount = 3,
  });

  static const slotKey = ValueKey<String>('input-phase-progress');

  /// Zero-based index of the current input step.
  final int stepIndex;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration =
        reduceMotion ? Duration.zero : const Duration(milliseconds: 280);
    final caption = DecisionCopy.inputPhaseStepLabel(stepIndex);

    return Padding(
      key: slotKey,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Semantics(
        liveRegion: true,
        label: caption,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (var i = 0; i < stepCount; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _Segment(
                        filled: i <= stepIndex,
                        duration: duration,
                        idleColor: colors.borderDefault,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: duration,
                child: Text(
                  caption,
                  key: ValueKey<String>(caption),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
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

class _Segment extends StatelessWidget {
  const _Segment({
    required this.filled,
    required this.duration,
    required this.idleColor,
  });

  final bool filled;
  final Duration duration;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: duration,
      curve: Curves.easeOutCubic,
      height: 6,
      decoration: BoxDecoration(
        color: filled ? TwiffelTokens.primaryDefault : idleColor,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}
