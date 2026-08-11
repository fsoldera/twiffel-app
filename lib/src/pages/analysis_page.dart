import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../copy/loading_response_texts.dart';
import '../models/decision_models.dart';
import '../services/report_pdf_builder.dart';
import '../state/app_settings_controller.dart';
import '../state/session_controller.dart';
import '../theme/tokens.dart';
import '../widgets/loading_animation.dart';
import '../widgets/twiffel_header.dart';
import 'decision_copy.dart';

/// Figma results screens: single (Pros/Cons) and comparison (Option A/B).
class AnalysisPage extends StatefulWidget {
  const AnalysisPage({
    super.key,
    required this.session,
    required this.settings,
  });

  final SessionController session;
  final AppSettingsController settings;

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _share(DecisionAnalysis analysis) async {
    var dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        );
      },
    );

    void closeDialog() {
      if (!dialogOpen || !mounted) return;
      dialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      // Device locale drives footer date and the share filename.
      final locale = View.of(context).platformDispatcher.locale;
      final bytes = await ReportPdfBuilder.build(
        analysis,
        locale: locale,
      );
      final filename = await ReportPdfBuilder.filenameFor(locale: locale);
      if (!mounted) return;
      closeDialog();
      final shared = await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
      );
      if (!shared && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(DecisionCopy.analysisShareFailed)),
        );
      }
    } catch (error, stack) {
      debugPrint('PDF share failed: $error\n$stack');
      if (!mounted) return;
      closeDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(DecisionCopy.analysisShareFailed)),
      );
    }
  }

  void _navigateHome() {
    widget.session.reset();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/');
    }
  }

  Future<void> _confirmStartOver() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(DecisionCopy.analysisStartOverTitle),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DecisionCopy.analysisStartOverBody),
              SizedBox(height: 12),
              Text(DecisionCopy.analysisStartOverBodyPdf),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(DecisionCopy.analysisStartOverKeep),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(DecisionCopy.analysisStartOverConfirm),
            ),
          ],
        );
      },
    );
    if (!mounted || confirmed != true) return;
    _navigateHome();
  }

  void _cancelLoading() {
    widget.session.cancelAnalysis();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.session,
      builder: (context, _) {
        final session = widget.session;
        final loading = session.phase == SessionPhase.loading;
        final error = session.phase == SessionPhase.error;
        final analysis = session.analysis;
        final isComparison = analysis?.mode == DecisionMode.comparison;
        final reduceMotion = MediaQuery.disableAnimationsOf(context);

        final colors = TwiffelColors.of(context);

        final Widget body;
        if (loading) {
          body = _LoadingBody(
            key: const ValueKey<String>('loading'),
            request: session.request,
            onCancel: _cancelLoading,
          );
        } else if (error || analysis == null) {
          body = _ErrorBody(
            key: const ValueKey<String>('error'),
            message: session.inputError ?? DecisionCopy.analysisError,
            onStartOver: _navigateHome,
          );
        } else {
          body = KeyedSubtree(
            key: const ValueKey<String>('results'),
            child: _ResultsBody(
              analysis: analysis,
              isComparison: isComparison,
              pageIndex: _pageIndex,
              pageController: _pageController,
              onPageChanged: (index) => setState(() => _pageIndex = index),
              onShare: () => _share(analysis),
              onStartOver: _confirmStartOver,
            ),
          );
        }

        // Results (and the wait/error states on this route) are terminal: no
        // app/OS back to the form, only Share or Start over.
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (loading) {
              _cancelLoading();
              return;
            }
            if (error || analysis == null) {
              _navigateHome();
              return;
            }
            _confirmStartOver();
          },
          child: Scaffold(
            backgroundColor: colors.pageBg,
            body: SafeArea(
              child: Column(
                children: [
                  TwiffelHeader(settings: widget.settings),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 320),
                      reverseDuration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      child: body,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ResultsBody extends StatefulWidget {
  const _ResultsBody({
    required this.analysis,
    required this.isComparison,
    required this.pageIndex,
    required this.pageController,
    required this.onPageChanged,
    required this.onShare,
    required this.onStartOver,
  });

  final DecisionAnalysis analysis;
  final bool isComparison;
  final int pageIndex;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onShare;
  final Future<void> Function() onStartOver;

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody> {
  bool _verdictExpanded = false;
  int _optionIndex = 0;
  /// +1 toward Option B, -1 toward Option A (list slide direction).
  int _optionDirection = 1;

  void _setVerdictExpanded(bool expanded) {
    if (_verdictExpanded == expanded) return;
    setState(() => _verdictExpanded = expanded);
  }

  void _selectAspect(int index) {
    widget.onPageChanged(index);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      widget.pageController.jumpToPage(index);
      return;
    }
    widget.pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _selectOption(int index) {
    if (index == _optionIndex) return;
    setState(() {
      _optionDirection = index > _optionIndex ? 1 : -1;
      _optionIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final analysis = widget.analysis;
    final isComparison = widget.isComparison;
    final pageIndex = widget.pageIndex;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final optionSwitchDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);
    final optionDirection = _optionDirection;

    final List<AnalysisPoint> pros;
    final List<AnalysisPoint> cons;
    if (isComparison) {
      pros = _optionIndex == 0 ? analysis.optionAPros : analysis.optionBPros;
      cons = _optionIndex == 0 ? analysis.optionACons : analysis.optionBCons;
    } else {
      pros = analysis.pros;
      cons = analysis.cons;
    }

    // Sticky action row: padding 12+8 + button height (scales with text size).
    final buttonHeight = MediaQuery.textScalerOf(context).scale(48);
    final stickyHeight = 20 + buttonHeight;

    final pointsPager = PageView(
      controller: widget.pageController,
      onPageChanged: widget.onPageChanged,
      children: [
        _PointsPanel(
          key: const ValueKey<String>('pros'),
          heading: DecisionCopy.analysisPros,
          accent: TwiffelTokens.semanticSuccess,
          icon: Icons.check,
          points: pros,
          showOverflowCue: pageIndex == 0,
        ),
        _PointsPanel(
          key: const ValueKey<String>('cons'),
          heading: DecisionCopy.analysisCons,
          accent: TwiffelTokens.semanticError,
          icon: Icons.close,
          points: cons,
          showOverflowCue: pageIndex == 1,
        ),
      ],
    );

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                isComparison
                    ? DecisionCopy.analysisTitleComparison
                    : DecisionCopy.analysisTitleSingle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _AspectSlider(
                labels: const [
                  DecisionCopy.analysisPros,
                  DecisionCopy.analysisCons,
                ],
                activeIndex: pageIndex,
                onChanged: _selectAspect,
              ),
            ),
            if (isComparison) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _OptionButtons(
                  optionA: analysis.optionA?.trim().isNotEmpty == true
                      ? analysis.optionA!
                      : DecisionCopy.analysisOptionALabel,
                  optionB: analysis.optionB?.trim().isNotEmpty == true
                      ? analysis.optionB!
                      : DecisionCopy.analysisOptionBLabel,
                  activeIndex: _optionIndex,
                  onChanged: _selectOption,
                ),
              ),
            ],
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: isComparison
                        ? AnimatedSwitcher(
                            duration: optionSwitchDuration,
                            reverseDuration: optionSwitchDuration,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            layoutBuilder: (currentChild, previousChildren) {
                              return Stack(
                                fit: StackFit.expand,
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
                              final isIncoming =
                                  child.key == ValueKey<int>(_optionIndex);
                              final begin = Offset(
                                0.07 *
                                    (isIncoming
                                        ? optionDirection
                                        : -optionDirection),
                                0,
                              );
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: begin,
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              );
                            },
                            child: KeyedSubtree(
                              key: ValueKey<int>(_optionIndex),
                              child: pointsPager,
                            ),
                          )
                        : pointsPager,
                  ),
                  // Reserve collapsed verdict height so list content does not jump.
                  const SizedBox(height: 68),
                ],
              ),
            ),
            // Layout spacer matching the sticky bar (drawn in the Stack).
            SizedBox(height: stickyHeight),
          ],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: stickyHeight,
          child: _StickyResultsActions(
            onStartOver: widget.onStartOver,
            onShare: widget.onShare,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: stickyHeight,
          child: IgnorePointer(
            ignoring: !_verdictExpanded,
            child: AnimatedOpacity(
              opacity: _verdictExpanded ? 1 : 0,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _setVerdictExpanded(false),
                child: const ColoredBox(color: Color(0x66000000)),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          // Keep a top bound so AnimatedSize can grow upward from the sticky
          // actions without jumping layout when expanding.
          top: 12,
          bottom: stickyHeight + 12,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _VerdictBar(
              verdictPoints: analysis.verdictPoints,
              expanded: _verdictExpanded,
              onExpandedChanged: _setVerdictExpanded,
            ),
          ),
        ),
      ],
    );
  }
}

class _StickyResultsActions extends StatelessWidget {
  const _StickyResultsActions({
    required this.onStartOver,
    required this.onShare,
  });

  final Future<void> Function() onStartOver;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final buttonHeight = MediaQuery.textScalerOf(context).scale(48);
    final iconSize = MediaQuery.textScalerOf(context).scale(16);
    final radius = buttonHeight / 2;

    return Material(
      color: colors.pageBg,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: onStartOver,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.borderDefault),
                  minimumSize: Size.fromHeight(buttonHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.center,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                child: const Text(
                  DecisionCopy.analysisStartOver,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onShare,
                icon: Icon(Icons.ios_share, size: iconSize),
                label: const Text(
                  DecisionCopy.analysisShare,
                  textAlign: TextAlign.center,
                ),
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(buttonHeight),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBody extends StatefulWidget {
  const _LoadingBody({
    super.key,
    this.request,
    required this.onCancel,
  });

  final DecisionRequest? request;
  final VoidCallback onCancel;

  @override
  State<_LoadingBody> createState() => _LoadingBodyState();
}

class _LoadingBodyState extends State<_LoadingBody> {
  late String _message;
  bool _showCancel = false;
  bool _subjectVisible = false;
  Timer? _rotateTimer;
  Timer? _cancelTimer;

  static const _cancelDelay = Duration(seconds: 8);
  static const _rotateInterval = Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();
    _message = LoadingResponseTexts.next();
    _cancelTimer = Timer(_cancelDelay, () {
      if (!mounted) return;
      setState(() => _showCancel = true);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _subjectVisible = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _rotateTimer?.cancel();
      _rotateTimer = null;
      return;
    }
    _rotateTimer ??= Timer.periodic(_rotateInterval, (_) {
      if (!mounted) return;
      setState(() => _message = LoadingResponseTexts.next());
    });
  }

  @override
  void dispose() {
    _rotateTimer?.cancel();
    _cancelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final request = widget.request;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final lineDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 360);
    final subjectDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 480);

    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 88),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _ShimmerThinkingLabel(),
                const SizedBox(height: 16),
                const TwiffelLoadingAnimation(height: 96),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: lineDuration,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
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
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: Text(
                    _message,
                    key: ValueKey<String>(_message),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
                if (request != null) ...[
                  const SizedBox(height: 20),
                  AnimatedOpacity(
                    opacity: _subjectVisible ? 1 : 0,
                    duration: subjectDuration,
                    curve: Curves.easeOut,
                    child: AnimatedSlide(
                      offset: _subjectVisible || reduceMotion
                          ? Offset.zero
                          : const Offset(0, 0.08),
                      duration: subjectDuration,
                      curve: Curves.easeOutCubic,
                      child: _LoadingSubject(request: request),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 16,
          child: AnimatedOpacity(
            opacity: _showCancel ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            child: IgnorePointer(
              ignoring: !_showCancel,
              child: Center(
                child: TextButton(
                  onPressed: widget.onCancel,
                  child: const Text(DecisionCopy.analysisCancel),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Full option text on the wait screen (no ellipsis). Comparison stacks A / VS / B.
class _LoadingSubject extends StatelessWidget {
  const _LoadingSubject({required this.request});

  final DecisionRequest request;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final style = TextStyle(
      color: colors.textTertiary,
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.35,
    );
    final vsStyle = TextStyle(
      color: TwiffelTokens.primaryDefault,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      height: 1.2,
    );

    if (request.mode == DecisionMode.comparison) {
      final optionA = request.optionA?.trim() ?? '';
      final optionB = request.optionB?.trim() ?? '';
      if (optionA.isEmpty && optionB.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        children: [
          if (optionA.isNotEmpty)
            Text(optionA, textAlign: TextAlign.center, style: style),
          if (optionA.isNotEmpty && optionB.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(DecisionCopy.analysisVsWord, textAlign: TextAlign.center, style: vsStyle),
            const SizedBox(height: 10),
          ],
          if (optionB.isNotEmpty)
            Text(optionB, textAlign: TextAlign.center, style: style),
        ],
      );
    }

    final target = request.target?.trim() ?? '';
    if (target.isEmpty) return const SizedBox.shrink();
    return Text(target, textAlign: TextAlign.center, style: style);
  }
}

/// Soft sweeping highlight over "Thinking...", similar to Cursor's Waiting...
class _ShimmerThinkingLabel extends StatefulWidget {
  const _ShimmerThinkingLabel();

  @override
  State<_ShimmerThinkingLabel> createState() => _ShimmerThinkingLabelState();
}

class _ShimmerThinkingLabelState extends State<_ShimmerThinkingLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final base = colors.textTertiary;
    final highlight = colors.isDark
        ? TwiffelTokens.gray100
        : TwiffelTokens.gray700;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    const label = Text(
      DecisionCopy.analysisThinking,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        height: 1.2,
      ),
    );

    if (reduceMotion) {
      return Text(
        DecisionCopy.analysisThinking,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: base,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          height: 1.2,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.8 + 3.6 * t, 0),
              end: Alignment(-0.6 + 3.6 * t, 0),
              colors: <Color>[base, base, highlight, base, base],
              stops: const <double>[0.0, 0.35, 0.5, 0.65, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: label,
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    super.key,
    required this.message,
    required this.onStartOver,
  });

  final String message;
  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onStartOver,
            child: const Text(DecisionCopy.analysisStartOver),
          ),
        ],
      ),
    );
  }
}

/// Sliding Pros / Cons control (shared track + moving thumb).
class _AspectSlider extends StatelessWidget {
  const _AspectSlider({
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    const radius = 999.0;
    const inset = 4.0;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final thumbDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final labelDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Container(
      decoration: BoxDecoration(
        color: colors.softFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.borderDefault),
      ),
      padding: const EdgeInsets.all(inset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / labels.length;

          return SizedBox(
            height: 44,
            width: constraints.maxWidth,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedPositioned(
                  duration: thumbDuration,
                  curve: Curves.easeOutCubic,
                  left: activeIndex * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: TwiffelTokens.primary400,
                      borderRadius: BorderRadius.circular(radius),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => onChanged(i),
                          borderRadius: BorderRadius.circular(radius),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: labelDuration,
                              curve: Curves.easeOut,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: activeIndex == i
                                    ? TwiffelTokens.gray900
                                    : colors.textPrimary,
                              ),
                              child: Text(
                                labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Distinct Option A / Option B buttons (not a shared slider track).
class _OptionButtons extends StatelessWidget {
  const _OptionButtons({
    required this.optionA,
    required this.optionB,
    required this.activeIndex,
    required this.onChanged,
  });

  final String optionA;
  final String optionB;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OptionButton(
            eyebrow: DecisionCopy.analysisOptionALabel,
            label: optionA,
            selected: activeIndex == 0,
            onTap: () => onChanged(0),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OptionButton(
            eyebrow: DecisionCopy.analysisOptionBLabel,
            label: optionB,
            selected: activeIndex == 1,
            onTap: () => onChanged(1),
          ),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.eyebrow,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String eyebrow;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final borderColor =
        selected ? TwiffelTokens.primaryDefault : colors.borderDefault;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.selectedFill : colors.softFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: duration,
                curve: Curves.easeOut,
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? TwiffelTokens.primaryDefault
                      : colors.borderDefault,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: selected
                            ? TwiffelTokens.primaryDefault
                            : colors.textTertiary,
                      ),
                      child: Text(
                        eyebrow.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: selected
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerdictBullet extends StatelessWidget {
  const _VerdictBullet({
    required this.text,
    required this.colors,
  });

  final String text;
  final TwiffelColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 7),
            child: Icon(
              Icons.circle,
              size: 6,
              color: TwiffelTokens.primaryDefault,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictBar extends StatelessWidget {
  const _VerdictBar({
    required this.verdictPoints,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final List<String> verdictPoints;
  final bool expanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final sizeDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);
    final fadeDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);

    final headerRow = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onExpandedChanged(!expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 10, 16),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                size: 18,
                color: TwiffelTokens.primaryDefault,
              ),
              const Expanded(
                child: Text(
                  DecisionCopy.analysisVerdictLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: TwiffelTokens.primaryDefault,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                expanded ? Icons.expand_more : Icons.keyboard_arrow_up,
                color: colors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );

    return Material(
      color: colors.softFill,
      elevation: expanded ? 8 : 0,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: sizeDuration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderDefault),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            headerRow,
            AnimatedSize(
              duration: sizeDuration,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? TweenAnimationBuilder<double>(
                      key: const ValueKey('verdict-fade'),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: fadeDuration,
                      curve: Curves.easeOut,
                      builder: (context, opacity, child) {
                        return Opacity(opacity: opacity, child: child);
                      },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight:
                              MediaQuery.sizeOf(context).height * 0.55,
                        ),
                        child: _OverflowScrollView(
                          key: const ValueKey('verdict-body'),
                          showOverflowCue: true,
                          shrinkWrap: true,
                          fadeColor: colors.softFill,
                          padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                          children: [
                            for (final point in verdictPoints)
                              _VerdictBullet(text: point, colors: colors),
                          ],
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightsHeading extends StatelessWidget {
  const _InsightsHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: TwiffelTokens.primary400,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: colors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _PointsPanel extends StatefulWidget {
  const _PointsPanel({
    super.key,
    required this.heading,
    required this.accent,
    required this.icon,
    required this.points,
    required this.showOverflowCue,
  });

  final String heading;
  final Color accent;
  final IconData icon;
  final List<AnalysisPoint> points;
  final bool showOverflowCue;

  @override
  State<_PointsPanel> createState() => _PointsPanelState();
}

class _PointsPanelState extends State<_PointsPanel>
    with SingleTickerProviderStateMixin {
  AnimationController? _stagger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _stagger?.dispose();
      _stagger = null;
      return;
    }
    if (_stagger != null) return;
    final count = widget.points.length.clamp(1, 8);
    _stagger = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 280 + (count - 1) * 55),
    )..forward();
  }

  @override
  void dispose() {
    _stagger?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final controller = _stagger;

    return _OverflowScrollView(
      showOverflowCue: widget.showOverflowCue,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      children: [
        _InsightsHeading(label: widget.heading),
        const SizedBox(height: 4),
        for (var i = 0; i < points.length; i++)
          if (controller == null)
            _PointRow(
              point: points[i],
              accent: widget.accent,
              icon: widget.icon,
            )
          else
            _StaggeredPointRow(
              animation: controller,
              index: i,
              total: points.length,
              child: _PointRow(
                point: points[i],
                accent: widget.accent,
                icon: widget.icon,
              ),
            ),
      ],
    );
  }
}

class _StaggeredPointRow extends StatelessWidget {
  const _StaggeredPointRow({
    required this.animation,
    required this.index,
    required this.total,
    required this.child,
  });

  final AnimationController animation;
  final int index;
  final int total;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final count = total.clamp(1, 8);
    final start = (index / count) * 0.55;
    final end = (start + 0.45).clamp(0.0, 1.0);
    final curve = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}

/// List that fades the bottom edge and shows a chevron while more content
/// remains below, so overflow is obvious even when a row ends at the clip.
class _OverflowScrollView extends StatefulWidget {
  const _OverflowScrollView({
    super.key,
    required this.children,
    required this.padding,
    required this.showOverflowCue,
    this.shrinkWrap = false,
    this.fadeColor,
  });

  final List<Widget> children;
  final EdgeInsets padding;
  final bool showOverflowCue;
  final bool shrinkWrap;
  /// Gradient/cue background; defaults to page background.
  final Color? fadeColor;

  @override
  State<_OverflowScrollView> createState() => _OverflowScrollViewState();
}

class _OverflowScrollViewState extends State<_OverflowScrollView> {
  final _controller = ScrollController();
  bool _canScrollDown = false;
  bool _updateScheduled = false;

  static const cueKey = ValueKey<String>('list-overflow-cue');

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateOverflow);
    _scheduleOverflowUpdate();
  }

  @override
  void didUpdateWidget(covariant _OverflowScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleOverflowUpdate();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateOverflow)
      ..dispose();
    super.dispose();
  }

  void _scheduleOverflowUpdate() {
    if (_updateScheduled) return;
    _updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScheduled = false;
      _updateOverflow();
    });
  }

  void _updateOverflow() {
    if (!mounted) return;
    if (!_controller.hasClients) {
      _scheduleOverflowUpdate();
      return;
    }
    final position = _controller.position;
    final canScrollDown = position.extentAfter > 1;
    if (canScrollDown != _canScrollDown) {
      setState(() => _canScrollDown = canScrollDown);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final fade = widget.fadeColor ?? colors.pageBg;

    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _updateOverflow();
        return false;
      },
      child: Stack(
        children: [
          ListView(
            controller: _controller,
            shrinkWrap: widget.shrinkWrap,
            physics: widget.shrinkWrap
                ? const ClampingScrollPhysics()
                : null,
            padding: widget.padding.copyWith(
              bottom: widget.padding.bottom + 28,
            ),
            children: widget.children,
          ),
          if (widget.showOverflowCue && _canScrollDown)
            Positioned(
              key: cueKey,
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            fade.withValues(alpha: 0),
                            fade.withValues(alpha: 0.85),
                            fade,
                          ],
                        ),
                      ),
                    ),
                    ColoredBox(
                      color: fade,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Center(
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: colors.softFill,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: TwiffelTokens.primaryDefault,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 28,
                              color: TwiffelTokens.primaryDefault,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.point,
    required this.accent,
    required this.icon,
  });

  final AnalysisPoint point;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  point.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  point.detail,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
