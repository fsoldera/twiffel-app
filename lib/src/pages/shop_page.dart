import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';

/// Placeholder shop / gratitude page. Customize or use [PaywallScreen] from the kit.
class ShopPage extends StatelessWidget {
  const ShopPage({super.key, required this.controller});

  final LicenseController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$kAppName — License')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thank you for supporting U-Things!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Real billing is not wired in this template yet. Replace this page '
              'with your paywall flow or the kit PaywallScreen when stores are ready.',
            ),
            const Spacer(),
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
