import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Twiffel loading mark from Figma `loading-animation` (`28:2`).
///
/// Left pill rises while the right pill drops (800ms ease-in-out loop).
class TwiffelLoadingAnimation extends StatefulWidget {
  const TwiffelLoadingAnimation({
    super.key,
    this.height = 78,
  });

  /// Matches Figma mark height (78). Width scales to 87:78.
  final double height;

  @override
  State<TwiffelLoadingAnimation> createState() =>
      _TwiffelLoadingAnimationState();
}

class _TwiffelLoadingAnimationState extends State<TwiffelLoadingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _bounce = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.height / 78;
    final colors = TwiffelColors.of(context);
    // On light surfaces, white pill would disappear; use brand navy instead.
    final rightPillColor =
        colors.isDark ? Colors.white : TwiffelTokens.gray800;

    return Semantics(
      label: 'Loading',
      child: SizedBox(
        width: 87 * scale,
        height: 78 * scale,
        child: AnimatedBuilder(
          animation: _bounce,
          builder: (context, _) {
            // Figma: left 0 → -12px, right 0 → +12px over the loop.
            final t = _bounce.value;
            final leftDy = -12 * scale * t;
            final rightDy = 12 * scale * t;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Left pill (rest top = 12 in 78-tall mark).
                Positioned(
                  left: 13 * scale,
                  top: 12 * scale + leftDy,
                  child: _Pill(
                    width: 26 * scale,
                    height: 51 * scale,
                    color: TwiffelTokens.primary600,
                  ),
                ),
                // Right pill (rest top = 0).
                Positioned(
                  left: 48 * scale,
                  top: 0 + rightDy,
                  child: _Pill(
                    width: 26 * scale,
                    height: 51 * scale,
                    color: rightPillColor,
                  ),
                ),
                // Balance bar (fixed).
                Positioned(
                  left: 0,
                  top: 71 * scale,
                  child: Container(
                    width: 87 * scale,
                    height: 7 * scale,
                    decoration: BoxDecoration(
                      color: TwiffelTokens.primary400,
                      borderRadius: BorderRadius.circular(3.5 * scale),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.width,
    required this.height,
    required this.color,
  });

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(width / 2),
      ),
    );
  }
}
