import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';

/// Placeholder shop / gratitude page. Customize or use [PaywallScreen] from the
/// kit.
///
/// Ships with the App Store compliance basics already wired in via the kit's
/// [platformStoreName] and [LegalLinksFooter] (guidelines 2.3.10 / 3.1.2(c)).
class ShopPage extends StatelessWidget {
  const ShopPage({super.key, required this.controller});

  final LicenseController controller;

  @override
  Widget build(BuildContext context) {
    final LicenseConfig config = controller.config;
    return Scaffold(
      appBar: AppBar(title: Text('$kAppName — License')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Thank you for supporting U-Things!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Real billing is not wired in this template yet. Replace this page '
              'with your paywall flow or the kit PaywallScreen when stores are ready.',
            ),
            const SizedBox(height: 12),
            Text(
              'When live, payment is processed securely by ${platformStoreName()}. '
              'Subscriptions are auto-renewable at the price shown per period '
              'until cancelled; manage or cancel any time in your '
              '${platformStoreName()} account settings.',
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
            const Spacer(),
            LegalLinksFooter(config: config),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.pop(),
              child: const Text('Back to app'),
            ),
          ],
        ),
      ),
    );
  }
}
