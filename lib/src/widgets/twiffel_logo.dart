import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../theme/tokens.dart';

/// Twiffel brand mark + wordmark, matching Figma logo assets.
///
/// Drawn in-widget so light/dark text adapts cleanly (exported PNGs ship with
/// opaque Figma preview backgrounds).
class TwiffelLogo extends StatelessWidget {
  const TwiffelLogo({
    super.key,
    this.height = 28,
    this.showWordmark = true,
  });

  final double height;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final emblemSize = height;

    final emblem = SizedBox(
      width: emblemSize,
      height: emblemSize,
      child: const CustomPaint(painter: _TwiffelMarkPainter()),
    );

    if (!showWordmark) {
      return Semantics(
        label: kAppName,
        child: emblem,
      );
    }

    return Semantics(
      label: kAppName,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          emblem,
          SizedBox(width: height * 0.28),
          Text(
            kAppName,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: height * 0.58,
              fontWeight: FontWeight.w700,
              height: 1,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon mark from Figma (64×64): navy tile, orange/white pills, amber base.
class _TwiffelMarkPainter extends CustomPainter {
  const _TwiffelMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 64;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, 64 * s, 64 * s),
        Radius.circular(8 * s),
      ),
      Paint()..color = TwiffelTokens.gray800,
    );

    // Left pill (orange), slightly lower.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(19 * s, 19 * s, 12 * s, 28 * s),
        Radius.circular(6 * s),
      ),
      Paint()..color = TwiffelTokens.primary600,
    );

    // Right pill (white), slightly higher.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(33 * s, 11 * s, 12 * s, 28 * s),
        Radius.circular(6 * s),
      ),
      Paint()..color = Colors.white,
    );

    // Horizontal amber base.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(14 * s, 51 * s, 36 * s, 4 * s),
        Radius.circular(2 * s),
      ),
      Paint()..color = TwiffelTokens.primary400,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
