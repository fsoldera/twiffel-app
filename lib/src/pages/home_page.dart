import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../state/session_controller.dart';

/// Starter home page — replace with your app's main UX.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.session,
    required this.license,
  });

  final SessionController session;
  final LicenseController license;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(kAppName),
            actions: [
              TextButton(
                onPressed: () => context.push('/shop'),
                child: const Text('Buy a license'),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Template home screen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter a task to call the Worker AI proxy (or local fallback). '
                  'Replace this page with your real app flow.',
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Task',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: session.submit,
                ),
                const SizedBox(height: 12),
                if (session.inputError != null)
                  Text(
                    session.inputError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                if (session.phase == SessionPhase.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (session.phase == SessionPhase.ready) ...[
                  const SizedBox(height: 16),
                  for (final step in session.steps)
                    ListTile(
                      leading: const Icon(Icons.check_circle_outline),
                      title: Text(step),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: session.reset,
                    child: const Text('Start over'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
