import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_settings_controller.dart';
import '../theme/tokens.dart';
import 'home_menu_button.dart';
import 'twiffel_logo.dart';

/// Centered Twiffel logo with optional back control or settings menu.
class TwiffelHeader extends StatelessWidget {
  const TwiffelHeader({
    super.key,
    this.showBack = false,
    this.settings,
    this.title,
    this.subtitle,
  });

  final bool showBack;
  final AppSettingsController? settings;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final showMenu = settings != null && !showBack;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showMenu)
            Row(
              children: [
                HomeMenuButton(settings: settings!),
                const Expanded(child: Center(child: TwiffelLogo(height: 32))),
                const SizedBox(width: 48),
              ],
            )
          else
            SizedBox(
              height: 36,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (showBack)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: colors.textSecondary,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.chevron_left, size: 20),
                        label: const Text(
                          'Back',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  const TwiffelLogo(height: 28),
                ],
              ),
            ),
          if (title != null) ...[
            const SizedBox(height: 16),
            Text(
              title!,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
