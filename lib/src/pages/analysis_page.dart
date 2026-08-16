import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../copy/loading_response_texts.dart';
import '../models/analysis_score.dart';
import '../models/decision_models.dart';
import '../services/report_pdf_builder.dart';
import '../state/app_settings_controller.dart';
import '../state/session_controller.dart';
import '../theme/tokens.dart';
import '../widgets/loop_play_video.dart';
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
  bool _showingDetails = false;
  /// 0 = Pros, 1 = Cons. Reset for each new analysis.
  int _detailsPageIndex = 0;
  /// 0 = Option A, 1 = Option B. Reset for each new analysis.
  int _detailsOptionIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_resetDetailsOnLoad);
  }

  @override
  void dispose() {
    widget.session.removeListener(_resetDetailsOnLoad);
    super.dispose();
  }

  void _resetDetailsOnLoad() {
    if (widget.session.phase != SessionPhase.loading) return;
    if (!_showingDetails &&
        _detailsPageIndex == 0 &&
        _detailsOptionIndex == 0) {
      return;
    }
    setState(() {
      _showingDetails = false;
      _detailsPageIndex = 0;
      _detailsOptionIndex = 0;
    });
  }

  void _openDetails() {
    setState(() => _showingDetails = true);
  }

  void _closeDetails() {
    if (!_showingDetails) return;
    setState(() => _showingDetails = false);
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
      // Device locale drives footer date, share filename, and email subject.
      final locale = View.of(context).platformDispatcher.locale;
      final generatedAt = DateTime.now();
      final bytes = await ReportPdfBuilder.build(
        analysis,
        locale: locale,
        generatedAt: generatedAt,
      );
      final filename = await ReportPdfBuilder.filenameFor(
        at: generatedAt,
        locale: locale,
      );
      final subject = await ReportPdfBuilder.shareSubjectFor(
        at: generatedAt,
        locale: locale,
      );
      if (!mounted) return;
      closeDialog();
      final shared = await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
        subject: subject,
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
            key: ValueKey<String>(
              _showingDetails ? 'results-details' : 'results-verdict',
            ),
            child: _showingDetails
                ? _ResultsBody(
                    analysis: analysis,
                    isComparison: isComparison,
                    pageIndex: _detailsPageIndex,
                    optionIndex: _detailsOptionIndex,
                    onPageIndexChanged: (index) {
                      setState(() => _detailsPageIndex = index);
                    },
                    onOptionIndexChanged: (index) {
                      setState(() => _detailsOptionIndex = index);
                    },
                    onShare: () => _share(analysis),
                    onStartOver: _confirmStartOver,
                  )
                : _VerdictPage(
                    analysis: analysis,
                    isComparison: isComparison,
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
            if (_showingDetails) {
              _closeDetails();
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
                  if (!loading && !error && analysis != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: _AspectSlider(
                        labels: const [
                          DecisionCopy.analysisSummaryTab,
                          DecisionCopy.analysisDetailsTab,
                        ],
                        outlined: true,
                        activeIndex: _showingDetails ? 1 : 0,
                        onChanged: (index) {
                          if (index == 1) {
                            _openDetails();
                          } else {
                            _closeDetails();
                          }
                        },
                      ),
                    ),
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
    required this.optionIndex,
    required this.onPageIndexChanged,
    required this.onOptionIndexChanged,
    required this.onShare,
    required this.onStartOver,
  });

  final DecisionAnalysis analysis;
  final bool isComparison;
  final int pageIndex;
  final int optionIndex;
  final ValueChanged<int> onPageIndexChanged;
  final ValueChanged<int> onOptionIndexChanged;
  final VoidCallback onShare;
  final Future<void> Function() onStartOver;

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody> {
  late final PageController _pageController;
  late int _pageIndex;
  late int _optionIndex;
  /// +1 toward Option B, -1 toward Option A (list slide direction).
  int _optionDirection = 1;

  @override
  void initState() {
    super.initState();
    _pageIndex = widget.pageIndex;
    _optionIndex = widget.optionIndex;
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectAspect(int index) {
    setState(() => _pageIndex = index);
    widget.onPageIndexChanged(index);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _pageController.jumpToPage(index);
      return;
    }
    _pageController.animateToPage(
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
    widget.onOptionIndexChanged(index);
  }

  Widget _aspectPage({
    required String heading,
    required Color accent,
    required IconData icon,
    required List<AnalysisPoint> points,
    required bool favorable,
    required Duration switchDuration,
  }) {
    final panel = _PointsPanel(
      key: ValueKey<String>('$heading-$_optionIndex'),
      heading: heading,
      accent: accent,
      icon: icon,
      points: points,
      favorable: favorable,
    );
    if (!widget.isComparison) return panel;

    final optionDirection = _optionDirection;
    final optionIndex = _optionIndex;
    return AnimatedSwitcher(
      duration: switchDuration,
      reverseDuration: switchDuration,
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
        if (switchDuration == Duration.zero) {
          return FadeTransition(opacity: animation, child: child);
        }
        final isIncoming = child.key == ValueKey<String>('$heading-$optionIndex');
        final begin = Offset(
          0.07 * (isIncoming ? optionDirection : -optionDirection),
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
      child: panel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;
    final isComparison = widget.isComparison;
    final pageIndex = _pageIndex;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final optionSwitchDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 280);

    final List<AnalysisPoint> pros;
    final List<AnalysisPoint> cons;
    if (isComparison) {
      pros = _optionIndex == 0 ? analysis.optionAPros : analysis.optionBPros;
      cons = _optionIndex == 0 ? analysis.optionACons : analysis.optionBCons;
    } else {
      pros = analysis.pros;
      cons = analysis.cons;
    }

    final pointsPager = PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() => _pageIndex = index);
        widget.onPageIndexChanged(index);
      },
      children: [
        _aspectPage(
          heading: DecisionCopy.analysisPros,
          accent: TwiffelTokens.semanticSuccess,
          icon: Icons.check,
          points: pros,
          favorable: true,
          switchDuration: optionSwitchDuration,
        ),
        _aspectPage(
          heading: DecisionCopy.analysisCons,
          accent: TwiffelTokens.semanticError,
          icon: Icons.close,
          points: cons,
          favorable: false,
          switchDuration: optionSwitchDuration,
        ),
      ],
    );

    return Column(
      children: [
        if (isComparison) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _AspectSlider(
              labels: [
                analysis.optionA?.trim().isNotEmpty == true
                    ? analysis.optionA!
                    : DecisionCopy.analysisOptionALabel,
                analysis.optionB?.trim().isNotEmpty == true
                    ? analysis.optionB!
                    : DecisionCopy.analysisOptionBLabel,
              ],
              activeIndex: _optionIndex,
              onChanged: _selectOption,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: EdgeInsets.fromLTRB(20, isComparison ? 0 : 8, 20, 0),
          child: _AspectSlider(
            labels: const [
              DecisionCopy.analysisPros,
              DecisionCopy.analysisCons,
            ],
            activeIndex: pageIndex,
            onChanged: _selectAspect,
            thumbColors: const [
              TwiffelTokens.semanticSuccess,
              TwiffelTokens.semanticError,
            ],
          ),
        ),
        Expanded(child: pointsPager),
        _StickyResultsActions(
          onSecondary: widget.onStartOver,
          secondaryLabel: DecisionCopy.analysisStartNewDecision,
          onPrimary: widget.onShare,
          primaryLabel: widget.isComparison
              ? DecisionCopy.analysisShareComparison
              : DecisionCopy.analysisShare,
        ),
      ],
    );
  }
}

class _VerdictPage extends StatelessWidget {
  const _VerdictPage({
    required this.analysis,
    required this.isComparison,
    required this.onShare,
    required this.onStartOver,
  });

  final DecisionAnalysis analysis;
  final bool isComparison;
  final VoidCallback onShare;
  final Future<void> Function() onStartOver;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final score = AnalysisScore.fromAnalysis(analysis);

    return Column(
      children: [
        Expanded(
          child: _ScrollOverflowFade(
            fadeKey: const ValueKey<String>('overflow-fade-summary'),
            child: ListView(
              key: const ValueKey<String>('verdict-body'),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              children: [
              Text(
                DecisionCopy.analysisVerdictLabel,
                style: TextStyle(
                  color: colors.textTertiary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              _VerdictHeadline(score: score),
              const SizedBox(height: 24),
              _SideBySideScores(score: score),
              const SizedBox(height: 24),
              Text(
                DecisionCopy.analysisKeyParameters,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              for (final point in analysis.verdictPoints) ...[
                _InsightCard(text: point, score: score),
                const SizedBox(height: 12),
              ],
              ],
            ),
          ),
        ),
        _StickyResultsActions(
          onSecondary: onStartOver,
          secondaryLabel: DecisionCopy.analysisStartNewDecision,
          onPrimary: onShare,
          primaryLabel: isComparison
              ? DecisionCopy.analysisShareComparison
              : DecisionCopy.analysisShare,
        ),
      ],
    );
  }
}

class _StickyResultsActions extends StatelessWidget {
  const _StickyResultsActions({
    required this.onSecondary,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.primaryLabel,
  });

  final Future<void> Function() onSecondary;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final buttonHeight = MediaQuery.textScalerOf(context).scale(47);

    return Material(
      color: colors.pageBg,
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.borderDefault)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                minimumSize: Size.fromHeight(buttonHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(buttonHeight / 2),
                ),
              ),
              child: Text(primaryLabel, textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onSecondary,
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.textPrimary,
                side: BorderSide(color: colors.borderDefault),
                minimumSize: Size.fromHeight(buttonHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(secondaryLabel, textAlign: TextAlign.center),
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
  late final String _message;
  bool _showCancel = false;
  bool _subjectVisible = false;
  Timer? _cancelTimer;

  static const _cancelDelay = Duration(seconds: 8);

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
  void dispose() {
    _cancelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final request = widget.request;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
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
                const LoopPlayVideo(),
                const SizedBox(height: 24),
                Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
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

class _VerdictHeadline extends StatelessWidget {
  const _VerdictHeadline({required this.score});

  final AnalysisScore score;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final base = GoogleFonts.outfit(
      fontWeight: FontWeight.w800,
      fontSize: 32,
      height: 1.15,
      color: colors.textPrimary,
    );
    if (score.strength == LeanStrength.tooClose) {
      return Text(score.headline, style: base);
    }
    final prefix = score.strength == LeanStrength.clear
        ? 'Clear lean to '
        : 'Slight lean to ';
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: prefix),
          TextSpan(
            text: score.favoredName,
            style: base.copyWith(color: TwiffelTokens.primaryDefault),
          ),
        ],
      ),
    );
  }
}

class _SideBySideScores extends StatelessWidget {
  const _SideBySideScores({required this.score});

  final AnalysisScore score;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = score.isComparison
        ? score.primaryLabel
        : DecisionCopy.analysisPros;
    final secondaryLabel = score.isComparison
        ? score.secondaryLabel
        : DecisionCopy.analysisCons;

    return Row(
      children: [
        Expanded(
          child: _FavorScoreCard(
            label: primaryLabel,
            percent: score.primaryFavorPercent,
            highlighted: score.strength != LeanStrength.tooClose &&
                score.leansPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FavorScoreCard(
            label: secondaryLabel,
            percent: score.secondaryFavorPercent,
            highlighted: score.strength != LeanStrength.tooClose &&
                !score.leansPrimary,
          ),
        ),
      ],
    );
  }
}

class _FavorScoreCard extends StatelessWidget {
  const _FavorScoreCard({
    required this.label,
    required this.percent,
    required this.highlighted,
  });

  final String label;
  final int percent;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    const checkSize = 22.0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.softFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: checkSize,
                height: checkSize,
                child: highlighted
                    ? const Icon(
                        Icons.check_circle,
                        size: checkSize,
                        color: TwiffelTokens.semanticSuccess,
                      )
                    : null,
              ),
              Expanded(
                child: Text(
                  formatLeanPercent(percent),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: checkSize),
            ],
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.text,
    required this.score,
  });

  final String text;
  final AnalysisScore score;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final tone = _insightTone(text, score);
    final borderColor = switch (tone) {
      _InsightTone.favorable => TwiffelTokens.semanticSuccess,
      _InsightTone.unfavorable => TwiffelTokens.semanticError,
      _InsightTone.neutral => colors.borderDefault,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.softFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 13,
            height: 1.4,
          ),
          children: _highlightNames(text, score),
        ),
      ),
    );
  }
}

enum _InsightTone { favorable, unfavorable, neutral }

_InsightTone _insightTone(String text, AnalysisScore score) {
  if (score.strength == LeanStrength.tooClose) return _InsightTone.neutral;
  final lower = text.toLowerCase();
  final winner = score.favoredName;
  final loser = score.leansPrimary ? score.secondaryLabel : score.primaryLabel;
  final mentionsWinner = _mentionsName(lower, winner, loser);
  final mentionsLoser = _mentionsName(lower, loser, winner);
  final againstLoser = mentionsLoser &&
      (lower.contains('against') ||
          lower.contains('weighs on') ||
          lower.contains('hurts') ||
          lower.contains('leaves more') ||
          lower.contains('cannot'));
  if (againstLoser || (mentionsLoser && !mentionsWinner)) {
    return _InsightTone.unfavorable;
  }
  if (mentionsWinner) return _InsightTone.favorable;
  return _InsightTone.favorable;
}

bool _mentionsName(String lowerText, String name, String otherName) {
  if (name.isEmpty) return false;
  if (lowerText.contains(name.toLowerCase())) return true;
  for (final token in distinctiveNameTokens(name, otherName)) {
    if (RegExp('\\b${RegExp.escape(token)}\\b').hasMatch(lowerText)) {
      return true;
    }
  }
  return false;
}

List<InlineSpan> _highlightNames(String text, AnalysisScore score) {
  if (!score.isComparison) {
    return [TextSpan(text: text)];
  }
  final winner = score.favoredName;
  final loser = score.leansPrimary ? score.secondaryLabel : score.primaryLabel;
  final needles = <({String text, Color color})>[
    if (winner.isNotEmpty)
      (text: winner, color: TwiffelTokens.semanticSuccess),
    if (loser.isNotEmpty) (text: loser, color: TwiffelTokens.semanticError),
  ]..sort((a, b) => b.text.length.compareTo(a.text.length));

  if (needles.isEmpty) return [TextSpan(text: text)];

  final spans = <InlineSpan>[];
  var remaining = text;
  while (remaining.isNotEmpty) {
    var matchStart = remaining.length;
    ({String text, Color color})? hit;
    for (final needle in needles) {
      final index = remaining.toLowerCase().indexOf(needle.text.toLowerCase());
      if (index >= 0 && index < matchStart) {
        matchStart = index;
        hit = needle;
      }
    }
    if (hit == null) {
      spans.add(TextSpan(text: remaining));
      break;
    }
    if (matchStart > 0) {
      spans.add(TextSpan(text: remaining.substring(0, matchStart)));
    }
    final matched = remaining.substring(matchStart, matchStart + hit.text.length);
    spans.add(
      TextSpan(
        text: matched,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: hit.color,
        ),
      ),
    );
    remaining = remaining.substring(matchStart + hit.text.length);
  }
  return spans;
}

class _AspectSlider extends StatelessWidget {
  const _AspectSlider({
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
    this.thumbColors,
    this.outlined = false,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;
  final List<Color>? thumbColors;
  final bool outlined;

  Color _labelColor({
    required TwiffelColors colors,
    required int index,
    required bool selected,
  }) {
    if (outlined) {
      return selected ? colors.textPrimary : colors.textSecondary;
    }
    if (thumbColors == null) {
      return selected ? TwiffelTokens.gray900 : colors.textPrimary;
    }
    if (selected) return TwiffelTokens.textOnPrimary;
    final accents = thumbColors;
    if (accents != null && index >= 0 && index < accents.length) {
      return accents[index];
    }
    return colors.textPrimary;
  }

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
          final accentColors = thumbColors;
          final thumbColor = accentColors != null &&
                  activeIndex >= 0 &&
                  activeIndex < accentColors.length
              ? accentColors[activeIndex]
              : TwiffelTokens.primary400;

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
                  child: AnimatedContainer(
                    duration: thumbDuration,
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: outlined ? Colors.transparent : thumbColor,
                      borderRadius: BorderRadius.circular(radius),
                      border: outlined
                          ? Border.all(color: colors.borderStrong)
                          : null,
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
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: labelDuration,
                                curve: Curves.easeOut,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _labelColor(
                                    colors: colors,
                                    index: i,
                                    selected: activeIndex == i,
                                  ),
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
    required this.favorable,
  });

  final String heading;
  final Color accent;
  final IconData icon;
  final List<AnalysisPoint> points;
  final bool favorable;

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

    return _ScrollOverflowFade(
      fadeKey: ValueKey<String>('overflow-fade-${widget.heading}'),
      child: ListView(
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
                favorable: widget.favorable,
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
                  favorable: widget.favorable,
                ),
              ),
        ],
      ),
    );
  }
}

class _ScrollOverflowFade extends StatefulWidget {
  const _ScrollOverflowFade({
    required this.child,
    required this.fadeKey,
  });

  final Widget child;
  final Key fadeKey;

  @override
  State<_ScrollOverflowFade> createState() => _ScrollOverflowFadeState();
}

class _ScrollOverflowFadeState extends State<_ScrollOverflowFade> {
  static const double _fadeHeight = 64;
  static const double _overflowEpsilon = 4;

  bool _showBottom = false;

  void _sync(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return;
    final show = metrics.maxScrollExtent > _overflowEpsilon &&
        metrics.extentAfter > _overflowEpsilon;
    if (show == _showBottom) return;
    setState(() => _showBottom = show);
  }

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) {
        _sync(notification.metrics);
        return false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          _sync(notification.metrics);
          return false;
        },
        child: Stack(
          children: [
            widget.child,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _fadeHeight,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  key: widget.fadeKey,
                  opacity: _showBottom ? 1 : 0,
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colors.pageBg.withValues(alpha: 0),
                          colors.pageBg.withValues(alpha: 0.72),
                          colors.pageBg,
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
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

class _WeightBadge extends StatelessWidget {
  const _WeightBadge({
    required this.weight,
    required this.accent,
    required this.favorable,
  });

  final int weight;
  final Color accent;
  final bool favorable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        signedWeightLabel(weight, favorable: favorable),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          height: 1.2,
          color: accent,
        ),
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({
    required this.point,
    required this.accent,
    required this.icon,
    required this.favorable,
  });

  final AnalysisPoint point;
  final Color accent;
  final IconData icon;
  final bool favorable;

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        point.tagline,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _WeightBadge(
                      weight: point.weight,
                      accent: accent,
                      favorable: favorable,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  point.description,
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
