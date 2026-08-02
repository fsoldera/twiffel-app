import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../state/app_settings_controller.dart';
import '../widgets/option_select_card.dart';
import '../widgets/sticky_primary_button.dart';
import '../widgets/twiffel_header.dart';
import 'decision_copy.dart';

enum DecisionPath { doOrBuy, thisOrThat }

/// Screen 1 – choose Path A (do/buy) or Path B (this/that).
class DecisionRoutingPage extends StatefulWidget {
  const DecisionRoutingPage({
    super.key,
    required this.settings,
  });

  final AppSettingsController settings;

  @override
  State<DecisionRoutingPage> createState() => _DecisionRoutingPageState();
}

class _DecisionRoutingPageState extends State<DecisionRoutingPage> {
  DecisionPath? _selected;

  void _continue() {
    final selected = _selected;
    if (selected == DecisionPath.doOrBuy) {
      context.push('/decision/do-or-buy');
    } else if (selected == DecisionPath.thisOrThat) {
      context.push('/decision/this-or-that');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: ListView(
                children: [
                  TwiffelHeader(
                    settings: widget.settings,
                    title: DecisionCopy.routingTitle,
                    subtitle: DecisionCopy.routingSubtitle,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      children: [
                        OptionSelectCard(
                          title: DecisionCopy.pathATitle,
                          helper: DecisionCopy.pathAHelper,
                          selected: _selected == DecisionPath.doOrBuy,
                          onTap: () => setState(
                            () => _selected = DecisionPath.doOrBuy,
                          ),
                        ),
                        const SizedBox(height: 16),
                        OptionSelectCard(
                          title: DecisionCopy.pathBTitle,
                          helper: DecisionCopy.pathBHelper,
                          selected: _selected == DecisionPath.thisOrThat,
                          onTap: () => setState(
                            () => _selected = DecisionPath.thisOrThat,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          StickyPrimaryButton(
            label: DecisionCopy.continueLabel,
            onPressed: _selected == null ? null : _continue,
          ),
        ],
      ),
    );
  }
}
