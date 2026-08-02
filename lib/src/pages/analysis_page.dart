import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../copy/loading_response_texts.dart';
import '../models/decision_models.dart';
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
    final buffer = StringBuffer()
      ..writeln(
        analysis.mode == DecisionMode.single
            ? DecisionCopy.analysisTitleSingle
            : DecisionCopy.analysisTitleComparison,
      )
      ..writeln()
      ..writeln(analysis.verdict);
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(DecisionCopy.analysisShareCopied)),
    );
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
            onStartOver: () {
              session.reset();
              context.go('/');
            },
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
              onStartOver: () {
                session.reset();
                context.go('/');
              },
              onBack: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
              },
            ),
          );
        }

        return Scaffold(
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
        );
      },
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({
    required this.analysis,
    required this.isComparison,
    required this.pageIndex,
    required this.pageController,
    required this.onPageChanged,
    required this.onShare,
    required this.onStartOver,
    required this.onBack,
  });

  final DecisionAnalysis analysis;
  final bool isComparison;
  final int pageIndex;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onShare;
  final VoidCallback onStartOver;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Column(
      children: [
        _TopBar(onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Text(
                  isComparison
                      ? DecisionCopy.analysisTitleComparison
                      : DecisionCopy.analysisTitleSingle,
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
                        label: DecisionCopy.analysisTargetLabel,
                        value: analysis.target ?? '',
                      ),
              ),
              const SizedBox(height: 20),
              _TabBar(
                labels: isComparison
                    ? [
                        '${DecisionCopy.analysisOptionALabel}: ${analysis.optionA ?? ''}',
                        '${DecisionCopy.analysisOptionBLabel}: ${analysis.optionB ?? ''}',
                      ]
                    : [
                        DecisionCopy.analysisPros,
                        DecisionCopy.analysisCons,
                      ],
                activeIndex: pageIndex,
                activeColor: isComparison
                    ? TwiffelTokens.primaryDefault
                    : (pageIndex == 0
                        ? TwiffelTokens.semanticSuccess
                        : TwiffelTokens.semanticError),
                inactiveColor: isComparison
                    ? colors.borderStrong
                    : (pageIndex == 0
                        ? TwiffelTokens.semanticError.withValues(alpha: 0.35)
                        : TwiffelTokens.semanticSuccess
                            .withValues(alpha: 0.35)),
                onTap: (index) {
                  onPageChanged(index);
                  pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                  );
                },
              ),
              SizedBox(
                height: isComparison ? 420 : 340,
                child: PageView(
                  controller: pageController,
                  onPageChanged: onPageChanged,
                  children: isComparison
                      ? [
                          _OptionPanel(
                            title:
                                '${DecisionCopy.analysisOptionALabel}: ${analysis.optionA ?? ''}',
                            pros: analysis.optionAPros,
                            cons: analysis.optionACons,
                          ),
                          _OptionPanel(
                            title:
                                '${DecisionCopy.analysisOptionBLabel}: ${analysis.optionB ?? ''}',
                            pros: analysis.optionBPros,
                            cons: analysis.optionBCons,
                          ),
                        ]
                      : [
                          _PointsPanel(
                            heading: DecisionCopy.analysisPros,
                            accent: TwiffelTokens.semanticSuccess,
                            icon: Icons.check,
                            points: analysis.pros,
                          ),
                          _PointsPanel(
                            heading: DecisionCopy.analysisCons,
                            accent: TwiffelTokens.semanticError,
                            icon: Icons.close,
                            points: analysis.cons,
                          ),
                        ],
                ),
              ),
              const SizedBox(height: 8),
              _SwipeHint(
                activeIndex: pageIndex,
                activeColor: isComparison
                    ? TwiffelTokens.primaryDefault
                    : (pageIndex == 0
                        ? TwiffelTokens.semanticSuccess
                        : TwiffelTokens.semanticError),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _VerdictBox(verdict: analysis.verdict),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onStartOver,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.textSecondary,
                          side: BorderSide(color: colors.borderDefault),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(DecisionCopy.analysisStartOver),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onShare,
                        icon: const Icon(Icons.ios_share, size: 16),
                        label: const Text(DecisionCopy.analysisShare),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left),
              color: colors.textSecondary,
            ),
            const Expanded(
              child: Center(child: TwiffelLogo(height: 28)),
            ),
            const SizedBox(width: 48),
          ],
        ),
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

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colors.softFill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.borderDefault),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
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
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonPills extends StatelessWidget {
  const _ComparisonPills({required this.analysis});

  final DecisionAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TargetPill(
          label: DecisionCopy.analysisOptionALabel,
          value: analysis.optionA ?? '',
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Text(
            'vs',
            style: TextStyle(
              color: TwiffelColors.of(context).textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        _TargetPill(
          label: DecisionCopy.analysisOptionBLabel,
          value: analysis.optionB ?? '',
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.labels,
    required this.activeIndex,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final List<String> labels;
  final int activeIndex;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.borderDefault),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Column(
                  children: [
                    Text(
                      labels[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            activeIndex == i ? FontWeight.w700 : FontWeight.w600,
                        color: activeIndex == i
                            ? colors.textPrimary
                            : colors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 3,
                      width: 44,
                      decoration: BoxDecoration(
                        color: activeIndex == i ? activeColor : inactiveColor,
                        borderRadius: BorderRadius.circular(2),
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

class _VerdictBox extends StatelessWidget {
  const _VerdictBox({required this.verdict});

  final String verdict;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.softFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: TwiffelTokens.primaryDefault,
              ),
              SizedBox(width: 6),
              Text(
                DecisionCopy.analysisVerdictLabel,
                style: TextStyle(
                  color: TwiffelTokens.primaryDefault,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            verdict,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsPanel extends StatelessWidget {
  const _PointsPanel({
    required this.heading,
    required this.accent,
    required this.icon,
    required this.points,
  });

  final String heading;
  final Color accent;
  final IconData icon;
  final List<AnalysisPoint> points;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 14, color: accent),
            ),
            const SizedBox(width: 8),
            Text(
              heading,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: TwiffelColors.of(context).textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final point in points) ...[
          _PointCard(point: point, accent: accent),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _OptionPanel extends StatelessWidget {
  const _OptionPanel({
    required this.title,
    required this.pros,
    required this.cons,
  });

  final String title;
  final List<AnalysisPoint> pros;
  final List<AnalysisPoint> cons;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        const _SectionLabel(
          icon: Icons.check,
          label: DecisionCopy.analysisPros,
          color: TwiffelTokens.semanticSuccess,
        ),
        const SizedBox(height: 8),
        for (final point in pros) ...[
          _PointCard(point: point, accent: TwiffelTokens.semanticSuccess),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 12),
        const _SectionLabel(
          icon: Icons.close,
          label: DecisionCopy.analysisCons,
          color: TwiffelTokens.semanticError,
        ),
        const SizedBox(height: 8),
        for (final point in cons) ...[
          _PointCard(point: point, accent: TwiffelTokens.semanticError),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PointCard extends StatelessWidget {
  const _PointCard({required this.point, required this.accent});

  final AnalysisPoint point;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final colors = TwiffelColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderDefault),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      point.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      point.detail,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
