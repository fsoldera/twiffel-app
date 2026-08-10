import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';

import '../copy/loading_response_texts.dart';
import '../models/decision_models.dart';
import '../services/report_pdf_builder.dart';
import '../state/session_controller.dart';
import '../theme/tokens.dart';
import '../widgets/loading_animation.dart';
import '../widgets/twiffel_logo.dart';
import 'decision_copy.dart';

/// Figma results screens: single (Pros/Cons) and comparison (Option A/B).
class AnalysisPage extends StatefulWidget {
  const AnalysisPage({
    super.key,
    required this.session,
  });

  final SessionController session;

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

  void _startOver() {
    widget.session.reset();
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

        final colors = TwiffelColors.of(context);

        final Widget body;
        if (loading) {
          body = const _LoadingBody(key: ValueKey<String>('loading'));
        } else if (error || analysis == null) {
          body = _ErrorBody(
            key: const ValueKey<String>('error'),
            message: session.inputError ?? DecisionCopy.analysisError,
            onStartOver: _startOver,
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
              onStartOver: _startOver,
            ),
          );
        }

        // Results (and the wait/error states on this route) are terminal: no
        // app/OS back to the form, only Share or Start over.
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _startOver();
          },
          child: Scaffold(
            backgroundColor: colors.pageBg,
            body: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                reverseDuration: const Duration(milliseconds: 260),
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
  final VoidCallback onStartOver;

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody> {
  bool _verdictExpanded = false;
  int _optionIndex = 0;

  void _setVerdictExpanded(bool expanded) {
    if (_verdictExpanded == expanded) return;
    setState(() => _verdictExpanded = expanded);
  }

  void _selectAspect(int index) {
    widget.onPageChanged(index);
    widget.pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);
    final analysis = widget.analysis;
    final isComparison = widget.isComparison;
    final pageIndex = widget.pageIndex;

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

    return Stack(
      children: [
        Column(
          children: [
            const _TopBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: isComparison
                  ? _ComparisonPills(analysis: analysis)
                  : _TargetPill(
                      label: DecisionCopy.analysisQuestionLabel,
                      value: analysis.target ?? '',
                    ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _TabBar(
                labels: [
                  '${DecisionCopy.analysisPros} (${pros.length})',
                  '${DecisionCopy.analysisCons} (${cons.length})',
                ],
                activeIndex: pageIndex,
                onTap: _selectAspect,
              ),
            ),
            if (isComparison) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _OptionSlider(
                  optionA: analysis.optionA?.trim().isNotEmpty == true
                      ? analysis.optionA!
                      : DecisionCopy.analysisOptionALabel,
                  optionB: analysis.optionB?.trim().isNotEmpty == true
                      ? analysis.optionB!
                      : DecisionCopy.analysisOptionBLabel,
                  activeIndex: _optionIndex,
                  onChanged: (index) => setState(() => _optionIndex = index),
                ),
              ),
            ],
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      controller: widget.pageController,
                      onPageChanged: widget.onPageChanged,
                      children: [
                        _PointsPanel(
                          key: ValueKey<String>('pros-$_optionIndex'),
                          heading: DecisionCopy.analysisPros,
                          accent: TwiffelTokens.semanticSuccess,
                          icon: Icons.check,
                          points: pros,
                          showOverflowCue: pageIndex == 0,
                        ),
                        _PointsPanel(
                          key: ValueKey<String>('cons-$_optionIndex'),
                          heading: DecisionCopy.analysisCons,
                          accent: TwiffelTokens.semanticError,
                          icon: Icons.close,
                          points: cons,
                          showOverflowCue: pageIndex == 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _SwipeHint(
                    activeIndex: pageIndex,
                    activeColor: pageIndex == 0
                        ? TwiffelTokens.semanticSuccess
                        : TwiffelTokens.semanticError,
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
              duration: const Duration(milliseconds: 200),
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
          // Expanded: occupy the band above the sticky bar, then center the
          // card vertically (shrink-wrap when short, max-height when tall).
          // Collapsed: sit just above the sticky bar.
          top: _verdictExpanded ? 12 : null,
          bottom: stickyHeight + 12,
          child: _verdictExpanded
              ? LayoutBuilder(
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight,
                        ),
                        child: _VerdictBar(
                          verdictPoints: analysis.verdictPoints,
                          expanded: true,
                          onExpandedChanged: _setVerdictExpanded,
                        ),
                      ),
                    );
                  },
                )
              : _VerdictBar(
                  verdictPoints: analysis.verdictPoints,
                  expanded: false,
                  onExpandedChanged: _setVerdictExpanded,
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

  final VoidCallback onStartOver;
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
                child: const Text(DecisionCopy.analysisStartOver),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: onShare,
                icon: Icon(Icons.ios_share, size: iconSize),
                label: const Text(DecisionCopy.analysisShare),
                style: FilledButton.styleFrom(
                  minimumSize: Size.fromHeight(buttonHeight),
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
  const _LoadingBody({super.key});

  @override
  State<_LoadingBody> createState() => _LoadingBodyState();
}

class _LoadingBodyState extends State<_LoadingBody> {
  late final String _message;

  @override
  void initState() {
    super.initState();
    _message = LoadingResponseTexts.next();
  }

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _ShimmerThinkingLabel(),
            const SizedBox(height: 16),
            const TwiffelLoadingAnimation(height: 96),
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
          ],
        ),
      ),
    );
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
    )..repeat();
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
      child: const Text(
        DecisionCopy.analysisThinking,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
          height: 1.2,
        ),
      ),
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

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 56,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Center(child: TwiffelLogo(height: 28)),
      ),
    );
  }
}

class _TargetPill extends StatelessWidget {
  const _TargetPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: colors.softFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderDefault),
      ),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: TwiffelTokens.primaryDefault,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonPills extends StatelessWidget {
  const _ComparisonPills({required this.analysis});

  final DecisionAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final optionA = analysis.optionA ?? '';
    final optionB = analysis.optionB ?? '';

    return _TargetPill(
      label: '${DecisionCopy.analysisOptionALabel} vs ${DecisionCopy.analysisOptionBLabel}',
      value: '$optionA  vs  $optionB',
    );
  }
}

/// Squared segmented slider for Option A / Option B (distinct from Pros/Cons pills).
class _OptionSlider extends StatelessWidget {
  const _OptionSlider({
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
    final colors = TwiffelColors.of(context);
    const radius = 12.0;
    const inset = 4.0;

    return Container(
      decoration: BoxDecoration(
        color: colors.softFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colors.borderStrong, width: 1.5),
      ),
      padding: const EdgeInsets.all(inset),
      // Measure after border + padding so the thumb never overruns the track.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 2;

          return SizedBox(
            height: 48,
            width: constraints.maxWidth,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  left: activeIndex * segmentWidth,
                  top: 0,
                  bottom: 0,
                  width: segmentWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.pageBg,
                      borderRadius: BorderRadius.circular(radius - 4),
                      border: Border.all(
                        color: TwiffelTokens.primaryDefault,
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1AD97706),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => onChanged(i),
                          borderRadius: BorderRadius.circular(radius - 4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  i == 0
                                      ? DecisionCopy.analysisOptionALabel
                                          .toUpperCase()
                                      : DecisionCopy.analysisOptionBLabel
                                          .toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.4,
                                    color: activeIndex == i
                                        ? TwiffelTokens.primaryDefault
                                        : colors.textTertiary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  i == 0 ? optionA : optionB,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: activeIndex == i
                                        ? colors.textPrimary
                                        : colors.textSecondary,
                                  ),
                                ),
                              ],
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

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.labels,
    required this.activeIndex,
    required this.onTap,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: activeIndex == i
                        ? TwiffelTokens.primary400
                        : colors.softFill,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: activeIndex == i
                          ? TwiffelTokens.primary400
                          : colors.borderDefault,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: activeIndex == i
                          ? TwiffelTokens.gray900
                          : colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SwipeHint extends StatelessWidget {
  const _SwipeHint({required this.activeIndex, required this.activeColor});

  final int activeIndex;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Column(
      children: [
        Text(
          DecisionCopy.analysisSwipeHint,
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 2; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: activeIndex == i ? activeColor : colors.borderDefault,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ],
        ),
      ],
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
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderDefault),
        ),
        clipBehavior: Clip.antiAlias,
        child: expanded
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  headerRow,
                  Flexible(
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
                ],
              )
            : headerRow,
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

class _PointsPanel extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return _OverflowScrollView(
      showOverflowCue: showOverflowCue,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      children: [
        _InsightsHeading(label: heading),
        const SizedBox(height: 4),
        for (var i = 0; i < points.length; i++)
          _PointRow(
            point: points[i],
            accent: accent,
            icon: icon,
            showDivider: i < points.length - 1,
          ),
      ],
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
    required this.showDivider,
  });

  final AnalysisPoint point;
  final Color accent;
  final IconData icon;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
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
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: colors.borderDefault,
          ),
      ],
    );
  }
}
