import 'package:common_app_kit/common_app_kit.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/decision_models.dart';
import '../state/app_settings_controller.dart';
import '../state/session_controller.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/once_play_video.dart';
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
  /// +1 forward, -1 back, for step slide direction.
  int _stepDirection = 1;
  int? _obstacleIndex;
  int? _timingIndex;
  DateTimeRange? _timingRange;
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
    DecisionCopy.timingDateRange,
  ];

  static const int _timingDateRangeIndex = 3;

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
        if (_timingIndex == null) return false;
        if (_timingIndex == _timingDateRangeIndex) {
          return _timingRange != null;
        }
        return true;
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

  String _timingLabel() {
    if (_timingIndex == _timingDateRangeIndex) {
      final range = _timingRange!;
      final locale = Localizations.localeOf(context).toString();
      final format = DateFormat.yMMMd(locale);
      return 'Between ${format.format(range.start)} and ${format.format(range.end)}';
    }
    return _timingOptions[_timingIndex!];
  }

  String? get _timingRangeSummary {
    final range = _timingRange;
    if (range == null) return null;
    final locale = Localizations.localeOf(context).toString();
    final format = DateFormat.yMMMd(locale);
    return '${format.format(range.start)} – ${format.format(range.end)}';
  }

  DecisionRequest _buildRequest() {
    return DecisionRequest(
      mode: DecisionMode.comparison,
      optionA: _optionAController.text.trim(),
      optionB: _optionBController.text.trim(),
      obstacle: _obstacleLabel(),
      timing: _timingLabel(),
    );
  }

  Future<void> _pickTimingRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: _timingRange,
      helpText: DecisionCopy.timingPickDates,
    );
    if (!mounted || picked == null) return;
    final start = picked.start;
    final end = picked.end.isBefore(picked.start) ? picked.start : picked.end;
    setState(() {
      _timingRange = DateTimeRange(start: start, end: end);
      _formError = null;
    });
  }

  void _onTimingSelected(int index) {
    setState(() {
      _timingIndex = index;
      if (index != _timingDateRangeIndex) {
        _timingRange = null;
      }
    });
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
      _stepDirection = -1;
      _step -= 1;
    });
  }

  Future<void> _goNext() async {
    if (!_canAdvance || _submitting) return;
    if (!_validateCurrentStep()) return;

    if (!_isLastStep) {
      setState(() {
        _stepDirection = 1;
        _step += 1;
      });
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
          onSelected: _onTimingSelected,
          dateRangeOptionIndex: _timingDateRangeIndex,
          dateRangeSummary: _timingRangeSummary,
          pickDatesLabel: DecisionCopy.timingPickDates,
          onPickDates: _pickTimingRange,
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

  Widget _stepContent() {
    return Column(
      key: ValueKey<int>(_step),
      mainAxisAlignment: _step == 0
          ? MainAxisAlignment.start
          : MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_step == 0) ...[
          const OncePlayVideo(),
          const SizedBox(height: 16),
        ],
        Text(
          _stepTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        _stepBody(),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 320);
    final direction = _stepDirection;

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
                              child: AnimatedSwitcher(
                                duration: duration,
                                reverseDuration: duration,
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                layoutBuilder: (currentChild, previousChildren) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: <Widget>[
                                      ...previousChildren,
                                      if (currentChild != null) currentChild,
                                    ],
                                  );
                                },
                                transitionBuilder: (child, animation) {
                                  if (reduceMotion) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    );
                                  }
                                  // Shared-axis: forward out left / in from right
                                  // (and reverse when going back).
                                  final isIncoming =
                                      child.key == ValueKey<int>(_step);
                                  final begin = Offset(
                                    isIncoming
                                        ? 0.24 * direction
                                        : -0.18 * direction,
                                    0,
                                  );
                                  final offset = Tween<Offset>(
                                    begin: begin,
                                    end: Offset.zero,
                                  ).animate(animation);
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: offset,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _stepContent(),
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
