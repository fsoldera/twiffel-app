import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/decision_models.dart';
import '../state/app_settings_controller.dart';
import '../state/session_controller.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/radio_option_list.dart';
import '../widgets/segmented_choice.dart';
import '../widgets/sticky_nav_buttons.dart';
import '../widgets/twiffel_header.dart';
import 'decision_copy.dart';

/// Home form in three steps: options → consideration → timing.
class DecisionFormPage extends StatefulWidget {
  const DecisionFormPage({
    super.key,
    required this.session,
    required this.settings,
  });

  final SessionController session;
  final AppSettingsController settings;

  @override
  State<DecisionFormPage> createState() => _DecisionFormPageState();
}

class _DecisionFormPageState extends State<DecisionFormPage> {
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _otherController = TextEditingController();

  /// 0 = options, 1 = consideration, 2 = timing.
  int _step = 0;
  int? _obstacleIndex;
  int? _timingIndex;
  String? _formError;
  bool _submitting = false;

  static const _obstacleOptions = <String>[
    DecisionCopy.pathBObstacleCost,
    DecisionCopy.pathBObstacleTime,
    DecisionCopy.pathBObstacleUncertainty,
    DecisionCopy.pathBObstacleFear,
  ];

  static const _timingOptions = <String>[
    DecisionCopy.timingAsap,
    DecisionCopy.timingMonths,
    DecisionCopy.timingLater,
  ];

  bool get _isLastStep => _step >= 2;

  String get _stepTitle {
    switch (_step) {
      case 1:
        return DecisionCopy.considerationStepTitle;
      case 2:
        return DecisionCopy.timingStepTitle;
      default:
        return DecisionCopy.optionsStepTitle;
    }
  }

  bool get _canAdvance {
    switch (_step) {
      case 0:
        return _optionAController.text.trim().isNotEmpty &&
            _optionBController.text.trim().isNotEmpty;
      case 1:
        if (_obstacleIndex == null) return false;
        if (_obstacleIndex == _obstacleOptions.length &&
            _otherController.text.trim().isEmpty) {
          return false;
        }
        return true;
      case 2:
        return _timingIndex != null;
      default:
        return false;
    }
  }

  String _obstacleLabel() {
    if (_obstacleIndex == null) return '';
    if (_obstacleIndex == _obstacleOptions.length) {
      return _otherController.text.trim();
    }
    return _obstacleOptions[_obstacleIndex!];
  }

  DecisionRequest _buildRequest() {
    return DecisionRequest(
      mode: DecisionMode.comparison,
      optionA: _optionAController.text.trim(),
      optionB: _optionBController.text.trim(),
      obstacle: _obstacleLabel(),
      timing: _timingOptions[_timingIndex!],
    );
  }

  bool _validateCurrentStep() {
    if (_step == 0) {
      final a = validateTaskInput(_optionAController.text.trim());
      if (!a.isValid) {
        setState(() => _formError = a.message);
        return false;
      }
      final b = validateTaskInput(_optionBController.text.trim());
      if (!b.isValid) {
        setState(() => _formError = b.message);
        return false;
      }
    } else if (_step == 1 && _obstacleIndex == _obstacleOptions.length) {
      final otherValidation = validateTaskInput(_otherController.text.trim());
      if (!otherValidation.isValid) {
        setState(() => _formError = otherValidation.message);
        return false;
      }
    }
    setState(() => _formError = null);
    return true;
  }

  void _goPrevious() {
    if (_step <= 0 || _submitting) return;
    setState(() {
      _formError = null;
      _step -= 1;
    });
  }

  Future<void> _goNext() async {
    if (!_canAdvance || _submitting) return;
    if (!_validateCurrentStep()) return;

    if (!_isLastStep) {
      setState(() => _step += 1);
      return;
    }

    setState(() {
      _formError = null;
      _submitting = true;
    });

    final future = widget.session.submitDecision(_buildRequest());
    if (!mounted) return;
    context.pushReplacement('/analysis');
    await future;
    if (!mounted) return;
    setState(() => _submitting = false);
  }

  @override
  void dispose() {
    _optionAController.dispose();
    _optionBController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  Widget _stepBody() {
    switch (_step) {
      case 1:
        return RadioOptionList(
          // Title already carries the question.
          label: '',
          helper: DecisionCopy.obstacleHelper,
          options: _obstacleOptions,
          otherLabel: DecisionCopy.otherLabel,
          selectedIndex: _obstacleIndex,
          otherController: _otherController,
          onSelected: (index) => setState(() => _obstacleIndex = index),
          onOtherChanged: (_) => setState(() {}),
        );
      case 2:
        return SegmentedChoice(
          // Title already carries the question.
          label: '',
          helper: DecisionCopy.timingHelper,
          options: _timingOptions,
          selectedIndex: _timingIndex,
          onSelected: (index) => setState(() => _timingIndex = index),
        );
      default:
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
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  TwiffelHeader(settings: widget.settings),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    _stepTitle,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  const SizedBox(height: 20),
                                  _stepBody(),
                                  if (_formError != null) ...[
                                    const SizedBox(height: 16),
                                    Text(
                                      _formError!,
                                      style: TextStyle(
                                        color: colors.error,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          StickyNavButtons(
            previousLabel: DecisionCopy.previousLabel,
            nextLabel: _isLastStep
                ? DecisionCopy.generateAnalysis
                : DecisionCopy.nextLabel,
            onPrevious: _step > 0 && !_submitting ? _goPrevious : null,
            onNext: _canAdvance && !_submitting ? _goNext : null,
            nextLoading: _submitting,
          ),
        ],
      ),
    );
  }
}
