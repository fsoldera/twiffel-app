import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/decision_models.dart';
import '../state/session_controller.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/radio_option_list.dart';
import '../widgets/segmented_choice.dart';
import '../widgets/sticky_primary_button.dart';
import '../widgets/twiffel_header.dart';
import 'decision_copy.dart';
import 'decision_routing_page.dart';

/// Single-screen Path A / Path B decision form.
class DecisionFormPage extends StatefulWidget {
  const DecisionFormPage({
    super.key,
    required this.path,
    required this.session,
  });

  final DecisionPath path;
  final SessionController session;

  @override
  State<DecisionFormPage> createState() => _DecisionFormPageState();
}

class _DecisionFormPageState extends State<DecisionFormPage> {
  final _decisionController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _otherController = TextEditingController();

  int? _obstacleIndex;
  int? _timingIndex;
  String? _formError;
  bool _submitting = false;

  bool get _isPathA => widget.path == DecisionPath.doOrBuy;

  List<String> get _obstacleOptions => _isPathA
      ? const [
          DecisionCopy.pathAObstacleCost,
          DecisionCopy.pathAObstacleTime,
          DecisionCopy.pathAObstacleUncertainty,
          DecisionCopy.pathAObstacleFear,
        ]
      : const [
          DecisionCopy.pathBObstacleCost,
          DecisionCopy.pathBObstacleTime,
          DecisionCopy.pathBObstacleUncertainty,
          DecisionCopy.pathBObstacleFear,
        ];

  List<String> get _timingOptions => const [
        DecisionCopy.timingAsap,
        DecisionCopy.timingMonths,
        DecisionCopy.timingLater,
      ];

  bool get _canSubmit {
    if (_isPathA) {
      if (_decisionController.text.trim().isEmpty) return false;
    } else {
      if (_optionAController.text.trim().isEmpty) return false;
      if (_optionBController.text.trim().isEmpty) return false;
    }
    if (_obstacleIndex == null) return false;
    if (_obstacleIndex == _obstacleOptions.length &&
        _otherController.text.trim().isEmpty) {
      return false;
    }
    if (_timingIndex == null) return false;
    return true;
  }

  String _obstacleLabel() {
    if (_obstacleIndex == null) return '';
    if (_obstacleIndex == _obstacleOptions.length) {
      return _otherController.text.trim();
    }
    return _obstacleOptions[_obstacleIndex!];
  }

  DecisionRequest _buildRequest() {
    final obstacle = _obstacleLabel();
    final timing = _timingOptions[_timingIndex!];
    if (_isPathA) {
      return DecisionRequest(
        mode: DecisionMode.single,
        target: _decisionController.text.trim(),
        obstacle: obstacle,
        timing: timing,
      );
    }
    return DecisionRequest(
      mode: DecisionMode.comparison,
      optionA: _optionAController.text.trim(),
      optionB: _optionBController.text.trim(),
      obstacle: obstacle,
      timing: timing,
    );
  }

  Future<void> _generate() async {
    if (_isPathA) {
      final validation = validateTaskInput(_decisionController.text.trim());
      if (!validation.isValid) {
        setState(() => _formError = validation.message);
        return;
      }
    } else {
      final a = validateTaskInput(_optionAController.text.trim());
      if (!a.isValid) {
        setState(() => _formError = a.message);
        return;
      }
      final b = validateTaskInput(_optionBController.text.trim());
      if (!b.isValid) {
        setState(() => _formError = b.message);
        return;
      }
    }
    if (_obstacleIndex == _obstacleOptions.length) {
      final otherValidation = validateTaskInput(_otherController.text.trim());
      if (!otherValidation.isValid) {
        setState(() => _formError = otherValidation.message);
        return;
      }
    }

    setState(() {
      _formError = null;
      _submitting = true;
    });

    // Navigate immediately so analysis can show the Figma loading mark while
    // the Worker request runs. Replace the form route so OS/app back cannot
    // return to the filled form and regenerate.
    final future = widget.session.submitDecision(_buildRequest());
    if (!mounted) return;
    context.pushReplacement('/analysis');
    await future;
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _decisionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  Widget _decisionFields() {
    if (_isPathA) {
      return LabeledTextField(
        label: DecisionCopy.pathAField1Label,
        placeholder: DecisionCopy.pathAField1Placeholder,
        helper: DecisionCopy.pathAField1Helper,
        controller: _decisionController,
        onChanged: (_) => setState(() {}),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabeledTextField(
          label: DecisionCopy.pathBOptionALabel,
          placeholder: DecisionCopy.pathBOptionAPlaceholder,
          helper: DecisionCopy.pathBOptionAHelper,
          controller: _optionAController,
          minLines: 1,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 20),
        LabeledTextField(
          label: DecisionCopy.pathBOptionBLabel,
          placeholder: DecisionCopy.pathBOptionBPlaceholder,
          helper: DecisionCopy.pathBOptionBHelper,
          controller: _optionBController,
          minLines: 1,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
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
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  TwiffelHeader(
                    showBack: true,
                    title: _isPathA
                        ? DecisionCopy.pathAFormTitle
                        : DecisionCopy.pathBFormTitle,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _decisionFields(),
                        const SizedBox(height: 28),
                        RadioOptionList(
                          label: _isPathA
                              ? DecisionCopy.pathAObstacleLabel
                              : DecisionCopy.pathBObstacleLabel,
                          helper: DecisionCopy.obstacleHelper,
                          options: _obstacleOptions,
                          otherLabel: DecisionCopy.otherLabel,
                          selectedIndex: _obstacleIndex,
                          otherController: _otherController,
                          onSelected: (index) =>
                              setState(() => _obstacleIndex = index),
                          onOtherChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 28),
                        SegmentedChoice(
                          label: _isPathA
                              ? DecisionCopy.pathATimingLabel
                              : DecisionCopy.pathBTimingLabel,
                          helper: DecisionCopy.timingHelper,
                          options: _timingOptions,
                          selectedIndex: _timingIndex,
                          onSelected: (index) =>
                              setState(() => _timingIndex = index),
                        ),
                        if (_formError != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _formError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          StickyPrimaryButton(
            label: DecisionCopy.generateAnalysis,
            loading: _submitting,
            onPressed: _canSubmit && !_submitting ? _generate : null,
          ),
        ],
      ),
    );
  }
}
