import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/analysis_score.dart';
import '../models/decision_models.dart';
import '../pages/decision_copy.dart';

/// Builds Twiffel decision report PDFs entirely on-device (no server).
///
/// Layout follows Figma `report-page1-bars` (113:613) and the detailed
/// comparison pages in `113:6`, file `0N24YtcP8pal5jf3E21t92`.
class ReportPdfBuilder {
  ReportPdfBuilder._();

  static const _headerBg = PdfColor.fromInt(0xFF1F2937);
  static const _primary = PdfColor.fromInt(0xFFD97706);
  static const _primarySoft = PdfColor.fromInt(0xFFFBBF24);
  static const _textPrimary = PdfColor.fromInt(0xFF111827);
  static const _textSecondary = PdfColor.fromInt(0xFF4B5563);
  static const _textMuted = PdfColor.fromInt(0xFF9CA3AF);
  static const _border = PdfColor.fromInt(0xFFE5E7EB);
  static const _softFill = PdfColor.fromInt(0xFFF9FAFB);
  static const _success = PdfColor.fromInt(0xFF059669);
  static const _successSoft = PdfColor.fromInt(0xFFECFDF5);
  static const _error = PdfColor.fromInt(0xFFDC2626);
  static const _errorSoft = PdfColor.fromInt(0xFFFEF2F2);
  static const _successCmp = PdfColor.fromInt(0xFF10B981);
  static const _errorCmp = PdfColor.fromInt(0xFFEF4444);
  static const _white = PdfColor.fromInt(0xFFFFFFFF);
  static const _verdictFill = PdfColor.fromInt(0xFFFEF8EC);
  static const _verdictBorder = PdfColor.fromInt(0xFFFADFA6);
  static const _prosBanner = PdfColor.fromInt(0xFFECFDF5);
  static const _consBanner = PdfColor.fromInt(0xFFFEF2F2);
  static const _optionB = PdfColor.fromInt(0xFF0F766E);
  static const _footerHeight = 70.0;
  static const _pageBandGap = 16.0;

  static Future<Uint8List> build(
    DecisionAnalysis analysis, {
    DateTime? generatedAt,
    Locale? locale,
  }) async {
    final assets = await _ReportAssets.load();
    final when = generatedAt ?? DateTime.now();
    final resolvedLocale = locale ?? PlatformDispatcher.instance.locale;
    final dateLabel = await _formatFooterDate(when, resolvedLocale);

    final doc = pw.Document(
      title: analysis.mode == DecisionMode.comparison
          ? DecisionCopy.reportComparisonSubtitle
          : DecisionCopy.reportSingleSubtitle,
      author: 'Twiffel',
    );

    if (analysis.mode == DecisionMode.comparison) {
      _addComparisonPages(doc, analysis, assets, dateLabel);
    } else {
      _addSinglePages(doc, analysis, assets, dateLabel);
    }

    return doc.save();
  }

  /// Share filename, same wording as [shareSubjectFor], plus `.pdf`.
  ///
  /// Date and time use the device locale (or [locale] when provided). Characters
  /// that are illegal in file names (`/` `:` and similar) are replaced so Save
  /// and Forward keep a name that still reads like the email subject.
  static Future<String> filenameFor({
    DateTime? at,
    Locale? locale,
  }) async {
    final subject = await shareSubjectFor(at: at, locale: locale);
    return '${_fileSafe(subject)}.pdf';
  }

  /// Email subject when the user picks Mail from the share sheet:
  /// `Twiffel results <date> <time>`.
  static Future<String> shareSubjectFor({
    DateTime? at,
    Locale? locale,
  }) async {
    final parts = await _shareDateTimeParts(at: at, locale: locale);
    return '${DecisionCopy.analysisShareSubjectPrefix} ${parts.date} ${parts.time}';
  }

  static Future<({String date, String time})> _shareDateTimeParts({
    DateTime? at,
    Locale? locale,
  }) async {
    final when = at ?? DateTime.now();
    final resolved = locale ?? PlatformDispatcher.instance.locale;
    final localeName = resolved.toString();

    try {
      await initializeDateFormatting(localeName);
    } catch (_) {
      await initializeDateFormatting('en');
    }

    return (
      date: DateFormat.yMd(localeName).format(when),
      time: DateFormat.jms(localeName).format(when),
    );
  }

  static String _fileSafe(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '-')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static Future<String> _formatFooterDate(DateTime when, Locale locale) async {
    final localeName = locale.toString();
    try {
      await initializeDateFormatting(localeName);
    } catch (_) {
      await initializeDateFormatting('en');
    }
    return DateFormat.yMMMMd(localeName).format(when);
  }

  static void _addSinglePages(
    pw.Document doc,
    DecisionAnalysis analysis,
    _ReportAssets assets,
    String dateLabel,
  ) {
    final score = AnalysisScore.fromAnalysis(analysis);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(top: 64, bottom: _footerHeight),
        header: (context) => _headerWithGap(
          subtitle: DecisionCopy.reportSingleSubtitle,
          sparkles: assets.sparkles,
        ),
        footer: (context) => _footerWithGap(
          context: context,
          dateLabel: dateLabel,
          assets: assets,
        ),
        build: (context) => [
          _padded(_questionCard(analysis.target ?? '')),
          pw.SizedBox(height: 12),
          _padded(
            _verdictCard(
              title: DecisionCopy.reportVerdictSingle,
              verdictPoints: analysis.verdictPoints,
              sparkles: assets.sparkles,
              headline: score.headline,
            ),
          ),
          pw.SizedBox(height: 12),
          _padded(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _favorCard(
                    title: DecisionCopy.analysisPros,
                    percent: score.primaryFavorPercent,
                    preferred: score.strength != LeanStrength.tooClose &&
                        score.leansPrimary,
                    pros: analysis.pros,
                    cons: const [],
                    showCons: false,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _favorCard(
                    title: DecisionCopy.analysisCons,
                    percent: score.secondaryFavorPercent,
                    preferred: score.strength != LeanStrength.tooClose &&
                        !score.leansPrimary,
                    pros: const [],
                    cons: analysis.cons,
                    showPros: false,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          _padded(
            _leanBreakdown(
              leftLabel: DecisionCopy.analysisPros,
              rightLabel: DecisionCopy.analysisCons,
              leftColor: _primary,
              rightColor: _optionB,
              rows: [
                (
                  label: DecisionCopy.reportFavor,
                  left: score.primaryFavorPercent.toDouble(),
                  right: score.secondaryFavorPercent.toDouble(),
                  leftText: formatLeanPercent(score.primaryFavorPercent),
                  rightText: formatLeanPercent(score.secondaryFavorPercent),
                ),
                (
                  label: DecisionCopy.reportPointWeight,
                  left: score.proSumPrimary.toDouble(),
                  right: score.conSumPrimary.toDouble(),
                  leftText: '${score.proSumPrimary}',
                  rightText: '${score.conSumPrimary}',
                ),
              ],
            ),
          ),
          pw.NewPage(),
          _padded(
            _detailBanner(
              DecisionCopy.reportProsDetailedSingle,
              _success,
              _prosBanner,
            ),
          ),
          pw.SizedBox(height: 10),
          ..._singleDetailRows(
            points: analysis.pros,
            accent: _success,
            badgeBg: _successSoft,
            favorable: true,
          ),
          pw.NewPage(),
          _padded(
            _detailBanner(
              DecisionCopy.reportConsDetailedSingle,
              _error,
              _consBanner,
            ),
          ),
          pw.SizedBox(height: 10),
          ..._singleDetailRows(
            points: analysis.cons,
            accent: _error,
            badgeBg: _errorSoft,
            favorable: false,
          ),
        ],
      ),
    );
  }

  static void _addComparisonPages(
    pw.Document doc,
    DecisionAnalysis analysis,
    _ReportAssets assets,
    String dateLabel,
  ) {
    final optionA = analysis.optionA ?? DecisionCopy.analysisOptionALabel;
    final optionB = analysis.optionB ?? DecisionCopy.analysisOptionBLabel;
    final score = AnalysisScore.fromAnalysis(analysis);
    final preferA =
        score.strength != LeanStrength.tooClose && score.leansPrimary;
    final preferB =
        score.strength != LeanStrength.tooClose && !score.leansPrimary;

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(top: 64, bottom: _footerHeight),
        header: (context) => _headerWithGap(
          subtitle: DecisionCopy.reportComparisonSubtitle,
          sparkles: assets.sparkles,
        ),
        footer: (context) => _footerWithGap(
          context: context,
          dateLabel: dateLabel,
          assets: assets,
        ),
        build: (context) => [
          _vsBar(optionA: optionA, optionB: optionB),
          pw.SizedBox(height: 12),
          _padded(
            _verdictCard(
              title: DecisionCopy.reportVerdictComparison,
              verdictPoints: analysis.verdictPoints,
              sparkles: assets.sparkles,
              headline: score.headline,
            ),
          ),
          pw.SizedBox(height: 12),
          _padded(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _favorCard(
                    title: optionA,
                    percent: score.primaryFavorPercent,
                    preferred: preferA,
                    pros: analysis.optionAPros,
                    cons: analysis.optionACons,
                  ),
                ),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: _favorCard(
                    title: optionB,
                    percent: score.secondaryFavorPercent,
                    preferred: preferB,
                    pros: analysis.optionBPros,
                    cons: analysis.optionBCons,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          _padded(
            _leanBreakdown(
              leftLabel: optionA,
              rightLabel: optionB,
              leftColor: _primary,
              rightColor: _optionB,
              rows: [
                (
                  label: DecisionCopy.reportFavor,
                  left: score.primaryFavorPercent.toDouble(),
                  right: score.secondaryFavorPercent.toDouble(),
                  leftText: formatLeanPercent(score.primaryFavorPercent),
                  rightText: formatLeanPercent(score.secondaryFavorPercent),
                ),
                (
                  label: DecisionCopy.reportProsWeight,
                  left: score.proSumPrimary.toDouble(),
                  right: score.proSumSecondary.toDouble(),
                  leftText: '${score.proSumPrimary}',
                  rightText: '${score.proSumSecondary}',
                ),
                (
                  label: DecisionCopy.reportConsWeight,
                  left: score.conSumPrimary.toDouble(),
                  right: score.conSumSecondary.toDouble(),
                  leftText: '${score.conSumPrimary}',
                  rightText: '${score.conSumSecondary}',
                ),
              ],
            ),
          ),
          pw.NewPage(),
          _padded(
            _detailBanner(
              DecisionCopy.reportProsDetailed,
              _success,
              _prosBanner,
            ),
          ),
          pw.SizedBox(height: 10),
          _padded(_detailOptionHeadings(optionA, optionB)),
          pw.SizedBox(height: 8),
          ..._pairedPointRows(
            left: analysis.optionAPros,
            right: analysis.optionBPros,
            leftAccent: _successCmp,
            leftBadgeBg: _successSoft,
            rightAccent: _successCmp,
            rightBadgeBg: _successSoft,
            leftFavorable: true,
            rightFavorable: true,
            bubbleStyle: true,
            titleSize: 10,
            detailSize: 9,
            gutter: 16,
          ),
          pw.NewPage(),
          _padded(
            _detailBanner(
              DecisionCopy.reportConsDetailed,
              _error,
              _consBanner,
            ),
          ),
          pw.SizedBox(height: 10),
          _padded(_detailOptionHeadings(optionA, optionB)),
          pw.SizedBox(height: 8),
          ..._pairedPointRows(
            left: analysis.optionACons,
            right: analysis.optionBCons,
            leftAccent: _errorCmp,
            leftBadgeBg: _errorSoft,
            rightAccent: _errorCmp,
            rightBadgeBg: _errorSoft,
            leftFavorable: false,
            rightFavorable: false,
            bubbleStyle: true,
            titleSize: 10,
            detailSize: 9,
            gutter: 16,
          ),
        ],
      ),
    );
  }

  static pw.Widget _padded(pw.Widget child) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: child,
    );
  }

  static pw.Widget _headerWithGap({
    required String subtitle,
    required pw.Widget? sparkles,
  }) {
    return pw.Column(
      children: [
        _headerBand(subtitle: subtitle, sparkles: sparkles),
        pw.SizedBox(height: _pageBandGap),
      ],
    );
  }

  static pw.Widget _footerWithGap({
    required pw.Context context,
    required String dateLabel,
    required _ReportAssets assets,
  }) {
    return pw.Column(
      children: [
        pw.SizedBox(height: _pageBandGap),
        _footer(context: context, dateLabel: dateLabel, assets: assets),
      ],
    );
  }

  static pw.Widget _headerBand({
    required String subtitle,
    required pw.Widget? sparkles,
  }) {
    return pw.Container(
      height: 64,
      width: double.infinity,
      color: _headerBg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _brandMark(),
          pw.SizedBox(width: 7),
          pw.Text(
            'Twiffel',
            style: pw.TextStyle(
              color: _white,
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Spacer(),
          if (sparkles != null) ...[
            sparkles,
            pw.SizedBox(width: 8),
          ],
          pw.Text(
            subtitle.toUpperCase(),
            style: pw.TextStyle(
              color: _primarySoft,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Icon mark matching Figma `twiffel-icon-mark` (64×64): orange/white pills
  /// plus the amber horizontal bar under them.
  static pw.Widget _brandMark({double size = 26}) {
    final s = size / 64;
    final tileStroke = PdfColor.fromInt(0xFF374151);
    return pw.SizedBox(
      width: size,
      height: size,
      child: pw.Stack(
        children: [
          pw.Container(
            width: size,
            height: size,
            decoration: pw.BoxDecoration(
              color: _headerBg,
              borderRadius: pw.BorderRadius.circular(7.5 * s),
              border: pw.Border.all(color: tileStroke, width: 0.75),
            ),
          ),
          // Left pill (orange).
          pw.Positioned(
            left: 19 * s,
            top: 19 * s,
            child: pw.Container(
              width: 12 * s,
              height: 28 * s,
              decoration: pw.BoxDecoration(
                color: _primary,
                borderRadius: pw.BorderRadius.circular(6 * s),
              ),
            ),
          ),
          // Right pill (white), slightly higher.
          pw.Positioned(
            left: 33 * s,
            top: 11 * s,
            child: pw.Container(
              width: 12 * s,
              height: 28 * s,
              decoration: pw.BoxDecoration(
                color: _white,
                borderRadius: pw.BorderRadius.circular(6 * s),
              ),
            ),
          ),
          // Horizontal amber base bar.
          pw.Positioned(
            left: 14 * s,
            top: 51 * s,
            child: pw.Container(
              width: 36 * s,
              height: 4 * s,
              decoration: pw.BoxDecoration(
                color: _primarySoft,
                borderRadius: pw.BorderRadius.circular(2 * s),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer({
    required pw.Context context,
    required String dateLabel,
    required _ReportAssets assets,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(28, 8, 28, 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                child: pw.Text(
                  DecisionCopy.reportDownload,
                  textAlign: pw.TextAlign.left,
                  style: pw.TextStyle(
                    color: _headerBg,
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                dateLabel,
                style: const pw.TextStyle(color: _textMuted, fontSize: 10),
              ),
              pw.SizedBox(width: 12),
              pw.Container(width: 1, height: 12, color: _border),
              pw.SizedBox(width: 12),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(
                  color: _textSecondary,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              _storeBadge(
                artwork: assets.appStore,
                url: DecisionCopy.reportAppStoreUrl,
                fallbackLabel: DecisionCopy.reportAppStore,
              ),
              pw.SizedBox(width: 8),
              _storeBadge(
                artwork: assets.googlePlay,
                url: DecisionCopy.reportGooglePlayUrl,
                fallbackLabel: DecisionCopy.reportGooglePlay,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _questionCard(String question) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: _softFill,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            DecisionCopy.reportActiveQuestionLabel.toUpperCase(),
            style: pw.TextStyle(
              color: _primary,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            question,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              lineSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// One short MultiPage child per index so long lists paginate safely.
  static List<pw.Widget> _pairedPointRows({
    required List<AnalysisPoint> left,
    required List<AnalysisPoint> right,
    required PdfColor leftAccent,
    required PdfColor leftBadgeBg,
    required PdfColor rightAccent,
    required PdfColor rightBadgeBg,
    required bool leftFavorable,
    required bool rightFavorable,
    required bool bubbleStyle,
    required double titleSize,
    required double detailSize,
    required double gutter,
    bool cardChrome = false,
  }) {
    final count = left.length > right.length ? left.length : right.length;
    if (count == 0) {
      return [
        _padded(
          pw.Text(
            'None listed.',
            style: const pw.TextStyle(color: _textSecondary, fontSize: 10),
          ),
        ),
      ];
    }

    return [
      for (var i = 0; i < count; i++)
        _padded(
          pw.Container(
            margin: pw.EdgeInsets.only(bottom: bubbleStyle ? 10 : 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _pointCell(
                    point: i < left.length ? left[i] : null,
                    index: i,
                    accent: leftAccent,
                    badgeBg: leftBadgeBg,
                    favorable: leftFavorable,
                    bubbleStyle: bubbleStyle,
                    titleSize: titleSize,
                    detailSize: detailSize,
                    cardChrome: cardChrome,
                    isLast: i == count - 1,
                  ),
                ),
                pw.SizedBox(width: gutter),
                pw.Expanded(
                  child: _pointCell(
                    point: i < right.length ? right[i] : null,
                    index: i,
                    accent: rightAccent,
                    badgeBg: rightBadgeBg,
                    favorable: rightFavorable,
                    bubbleStyle: bubbleStyle,
                    titleSize: titleSize,
                    detailSize: detailSize,
                    cardChrome: cardChrome,
                    isLast: i == count - 1,
                  ),
                ),
              ],
            ),
          ),
        ),
    ];
  }

  static pw.Widget _pointCell({
    required AnalysisPoint? point,
    required int index,
    required PdfColor accent,
    required PdfColor badgeBg,
    required bool favorable,
    required bool bubbleStyle,
    required double titleSize,
    required double detailSize,
    required bool cardChrome,
    required bool isLast,
  }) {
    final body = point == null
        ? pw.SizedBox()
        : pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (bubbleStyle)
                pw.Container(
                  width: 16,
                  height: 16,
                  alignment: pw.Alignment.center,
                  decoration: pw.BoxDecoration(
                    color: badgeBg,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(
                    '${index + 1}',
                    style: pw.TextStyle(
                      color: accent,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                )
              else
                pw.SizedBox(
                  width: 12,
                  child: pw.Text(
                    '${index + 1}',
                    style: pw.TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              pw.SizedBox(width: bubbleStyle ? 8 : 6),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            point.tagline,
                            style: pw.TextStyle(
                              color: _textPrimary,
                              fontSize: titleSize,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        pw.Text(
                          signedWeightLabel(point.weight, favorable: favorable),
                          style: pw.TextStyle(
                            color: accent,
                            fontSize: titleSize,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      point.description,
                      style: pw.TextStyle(
                        color: _textSecondary,
                        fontSize: detailSize,
                        lineSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

    if (!cardChrome) return body;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: pw.BoxDecoration(
        color: _softFill,
        border: pw.Border(
          left: const pw.BorderSide(color: _border),
          right: const pw.BorderSide(color: _border),
          bottom: isLast
              ? const pw.BorderSide(color: _border)
              : pw.BorderSide.none,
        ),
      ),
      child: body,
    );
  }

  static pw.Widget _vsBar({
    required String optionA,
    required String optionB,
  }) {
    pw.Widget badge(String letter, PdfColor fill) {
      return pw.Container(
        width: 16,
        height: 16,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: fill,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Text(
          letter,
          style: pw.TextStyle(
            color: _white,
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      decoration: const pw.BoxDecoration(
        color: _softFill,
        border: pw.Border(bottom: pw.BorderSide(color: _border)),
      ),
      child: pw.Row(
        children: [
          badge('A', _headerBg),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              optionA.toUpperCase(),
              maxLines: 1,
              style: pw.TextStyle(
                color: _textPrimary,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10),
            child: pw.Text(
              DecisionCopy.analysisVsWord.toLowerCase(),
              style: const pw.TextStyle(color: _textMuted, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              optionB.toUpperCase(),
              maxLines: 1,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                color: _textPrimary,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 8),
          badge('B', _primary),
        ],
      ),
    );
  }

  static pw.Widget _favorCard({
    required String title,
    required int percent,
    required bool preferred,
    required List<AnalysisPoint> pros,
    required List<AnalysisPoint> cons,
    bool showPros = true,
    bool showCons = true,
  }) {
    pw.Widget list(String heading, List<AnalysisPoint> points, PdfColor accent) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            heading.toUpperCase(),
            style: pw.TextStyle(
              color: accent,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          for (var i = 0; i < points.length && i < 5; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Text(
                '${i + 1}. ${points[i].tagline}',
                maxLines: 2,
                style: const pw.TextStyle(color: _textPrimary, fontSize: 8),
              ),
            ),
        ],
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            maxLines: 2,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            DecisionCopy.reportFavor,
            style: const pw.TextStyle(color: _textMuted, fontSize: 8),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              pw.SizedBox(
                width: 12,
                height: 12,
                child: preferred ? _checkMark() : null,
              ),
              pw.Expanded(
                child: pw.Text(
                  formatLeanPercent(percent),
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
            ],
          ),
          if (showPros && showCons) ...[
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: list(DecisionCopy.analysisPros, pros, _success)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: list(DecisionCopy.analysisCons, cons, _error)),
              ],
            ),
          ] else if (showPros) ...[
            pw.SizedBox(height: 8),
            list(DecisionCopy.analysisPros, pros, _success),
          ] else if (showCons) ...[
            pw.SizedBox(height: 8),
            list(DecisionCopy.analysisCons, cons, _error),
          ],
        ],
      ),
    );
  }

  static pw.Widget _checkMark() {
    return pw.SvgImage(
      svg: '''<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
<circle cx="12" cy="12" r="12" fill="#10B981"/>
<path d="M6.5 12.2l3.4 3.4 7.6-7.6" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>
</svg>''',
    );
  }

  static pw.Widget _leanBreakdown({
    required String leftLabel,
    required String rightLabel,
    required PdfColor leftColor,
    required PdfColor rightColor,
    required List<
        ({
          String label,
          double left,
          double right,
          String leftText,
          String rightText,
        })> rows,
  }) {
    pw.Widget swatch(PdfColor color) {
      return pw.Container(
        width: 8,
        height: 8,
        decoration: pw.BoxDecoration(
          color: color,
          borderRadius: pw.BorderRadius.circular(1.5),
        ),
      );
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            children: [
              pw.Text(
                DecisionCopy.reportLeanBreakdown.toUpperCase(),
                style: pw.TextStyle(
                  color: _textPrimary,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Spacer(),
              swatch(leftColor),
              pw.SizedBox(width: 4),
              pw.Text(
                leftLabel,
                maxLines: 1,
                style: const pw.TextStyle(color: _textSecondary, fontSize: 8),
              ),
              pw.SizedBox(width: 10),
              swatch(rightColor),
              pw.SizedBox(width: 4),
              pw.Text(
                rightLabel,
                maxLines: 1,
                style: const pw.TextStyle(color: _textSecondary, fontSize: 8),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          for (final row in rows) ...[
            _leanRow(
              row: row,
              leftColor: leftColor,
              rightColor: rightColor,
            ),
            pw.SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  static pw.Widget _leanRow({
    required ({
      String label,
      double left,
      double right,
      String leftText,
      String rightText,
    }) row,
    required PdfColor leftColor,
    required PdfColor rightColor,
  }) {
    final peak = [row.left, row.right, 1].reduce((a, b) => a > b ? a : b);
    const maxBar = 78.0;
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 72,
          child: pw.Text(
            row.label,
            style: const pw.TextStyle(color: _textSecondary, fontSize: 8),
          ),
        ),
        pw.Expanded(
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text(
                row.leftText,
                style: pw.TextStyle(
                  color: _textPrimary,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Container(
                width: maxBar * (row.left / peak),
                height: 7,
                decoration: pw.BoxDecoration(
                  color: leftColor,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6),
          child: pw.Text(
            DecisionCopy.analysisVsWord.toLowerCase(),
            style: const pw.TextStyle(color: _textMuted, fontSize: 8),
          ),
        ),
        pw.Expanded(
          child: pw.Row(
            children: [
              pw.Container(
                width: maxBar * (row.right / peak),
                height: 7,
                decoration: pw.BoxDecoration(
                  color: rightColor,
                  borderRadius: pw.BorderRadius.circular(2),
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                row.rightText,
                style: pw.TextStyle(
                  color: _textPrimary,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _detailBanner(String title, PdfColor accent, PdfColor fill) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: fill,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: accent, width: 0.6),
      ),
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          color: accent,
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _detailOptionHeadings(String optionA, String optionB) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            optionA,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Text(
            optionB,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  static List<pw.Widget> _singleDetailRows({
    required List<AnalysisPoint> points,
    required PdfColor accent,
    required PdfColor badgeBg,
    required bool favorable,
  }) {
    if (points.isEmpty) {
      return [
        _padded(
          pw.Text(
            'None listed.',
            style: const pw.TextStyle(color: _textSecondary, fontSize: 10),
          ),
        ),
      ];
    }
    return [
      for (var i = 0; i < points.length; i++)
        _padded(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: _pointCell(
              point: points[i],
              index: i,
              accent: accent,
              badgeBg: badgeBg,
              favorable: favorable,
              bubbleStyle: true,
              titleSize: 11,
              detailSize: 10,
              cardChrome: false,
              isLast: i == points.length - 1,
            ),
          ),
        ),
    ];
  }

  static pw.Widget _verdictCard({
    required String title,
    required List<String> verdictPoints,
    required pw.Widget? sparkles,
    required String headline,
  }) {
    final items = verdictPoints.isEmpty ? const <String>[''] : verdictPoints;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _verdictFill,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _verdictBorder),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              if (sparkles != null) ...[
                sparkles,
                pw.SizedBox(width: 6),
              ],
              pw.Text(
                title.toUpperCase(),
                style: pw.TextStyle(
                  color: _primary,
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            headline,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          for (final point in items)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 3, right: 6),
                    child: pw.Container(
                      width: 4,
                      height: 4,
                      decoration: const pw.BoxDecoration(
                        color: _primary,
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      point,
                      style: const pw.TextStyle(
                        color: _textPrimary,
                        fontSize: 9,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _storeBadge({
    required pw.Widget? artwork,
    required String url,
    required String fallbackLabel,
  }) {
    return pw.UrlLink(
      destination: url,
      child: artwork ??
          pw.Text(
            fallbackLabel,
            style: pw.TextStyle(
              color: _primary,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
    );
  }
}

class _ReportAssets {
  const _ReportAssets({
    this.sparkles,
    this.appStore,
    this.googlePlay,
  });

  final pw.Widget? sparkles;
  final pw.Widget? appStore;
  final pw.Widget? googlePlay;

  /// Official badge height in PDF points. Google requires at least 28px digital.
  static const _badgeHeight = 28.0;
  static const _appStoreWidth = _badgeHeight * 119.66407 / 40;
  static const _playWidth = _badgeHeight * 239 / 70.9;

  static Future<_ReportAssets> load() async {
    return _ReportAssets(
      sparkles: await _svgIcon('assets/report/sparkles.svg', 14),
      appStore: await _svgBadge(
        'assets/report/badge-app-store.svg',
        width: _appStoreWidth,
        height: _badgeHeight,
      ),
      googlePlay: await _svgBadge(
        'assets/report/badge-google-play.svg',
        width: _playWidth,
        height: _badgeHeight,
      ),
    );
  }

  static Future<pw.Widget?> _svgIcon(String assetPath, double size) async {
    try {
      final svg = await rootBundle.loadString(assetPath);
      return pw.SizedBox(
        width: size,
        height: size,
        child: pw.SvgImage(svg: svg, fit: pw.BoxFit.contain),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<pw.Widget?> _svgBadge(
    String assetPath, {
    required double width,
    required double height,
  }) async {
    try {
      final svg = await rootBundle.loadString(assetPath);
      return pw.SizedBox(
        width: width,
        height: height,
        child: pw.SvgImage(svg: svg, fit: pw.BoxFit.contain),
      );
    } catch (_) {
      return null;
    }
  }
}
