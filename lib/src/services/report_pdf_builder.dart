import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/decision_models.dart';
import '../pages/decision_copy.dart';

/// Builds Twiffel decision report PDFs entirely on-device (no server).
///
/// Layout follows Figma `report-single-choice` (60:5) and `report-comparison`
/// (60:94) in file `0N24YtcP8pal5jf3E21t92`.
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

  /// Share filename: `Twiffel_results_<date>_<hh:mi:ss>.pdf`.
  ///
  /// Date and time use the device locale (or [locale] when provided). Characters
  /// that are illegal in file names are replaced so the share sheet can write
  /// the file on Android and iOS.
  static Future<String> filenameFor({
    DateTime? at,
    Locale? locale,
  }) async {
    final parts = await _shareDateTimeParts(at: at, locale: locale);
    return 'Twiffel_results_${_fileSafe(parts.date)}_${_fileSafe(parts.time)}.pdf';
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
        .replaceAll(RegExp(r'\s+'), '_');
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
    // Emit short MultiPage children (paired rows) so tall pros/cons lists can
    // paginate. A single unsplittable Row/Column taller than one page throws
    // PdfTooBigPageException.
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(top: 64, bottom: 44),
        header: (context) => _headerBand(
          subtitle: DecisionCopy.reportSingleSubtitle,
          sparkles: assets.sparkles,
        ),
        footer: (context) => _footer(
          context: context,
          dateLabel: dateLabel,
        ),
        build: (context) => [
          pw.SizedBox(height: 24),
          _padded(_questionCard(analysis.target ?? '')),
          pw.SizedBox(height: 20),
          _padded(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _columnHeader(
                    title: DecisionCopy.reportProsArguments,
                    accent: _success,
                    badgeBg: _successSoft,
                    count: analysis.pros.length,
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Expanded(
                  child: _columnHeader(
                    title: DecisionCopy.reportConsTradeoffs,
                    accent: _error,
                    badgeBg: _errorSoft,
                    count: analysis.cons.length,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          ..._pairedPointRows(
            left: analysis.pros,
            right: analysis.cons,
            leftAccent: _success,
            leftBadgeBg: _successSoft,
            rightAccent: _error,
            rightBadgeBg: _errorSoft,
            bubbleStyle: true,
            titleSize: 11,
            detailSize: 10,
            gutter: 20,
          ),
          pw.SizedBox(height: 20),
          _padded(
            _verdictCard(
              title: DecisionCopy.reportVerdictSingle,
              verdictPoints: analysis.verdictPoints,
              sparkles: assets.sparkles,
            ),
          ),
          pw.SizedBox(height: 16),
          _padded(_downloadSection(assets)),
          pw.SizedBox(height: 12),
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

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(top: 64, bottom: 44),
        header: (context) => _headerBand(
          subtitle: DecisionCopy.reportComparisonSubtitle,
          sparkles: assets.sparkles,
        ),
        footer: (context) => _footer(
          context: context,
          dateLabel: dateLabel,
        ),
        build: (context) => [
          pw.SizedBox(height: 24),
          _padded(
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: _optionMetaCard(
                    label: DecisionCopy.analysisOptionALabel,
                    value: optionA,
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: _optionMetaCard(
                    label: DecisionCopy.analysisOptionBLabel,
                    value: optionB,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 18),
          _padded(
            pw.Row(
              children: [
                pw.Expanded(
                  child: _comparisonHeading(
                    '${DecisionCopy.analysisOptionALabel}: $optionA',
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: _comparisonHeading(
                    '${DecisionCopy.analysisOptionBLabel}: $optionB',
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          _padded(
            pw.Row(
              children: [
                pw.Expanded(
                  child: _comparisonSectionHeader(
                    label: DecisionCopy.analysisPros,
                    accent: _successCmp,
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: _comparisonSectionHeader(
                    label: DecisionCopy.analysisPros,
                    accent: _successCmp,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          ..._pairedPointRows(
            left: analysis.optionAPros,
            right: analysis.optionBPros,
            leftAccent: _successCmp,
            leftBadgeBg: _softFill,
            rightAccent: _successCmp,
            rightBadgeBg: _softFill,
            bubbleStyle: false,
            titleSize: 10,
            detailSize: 9,
            gutter: 16,
            cardChrome: true,
          ),
          pw.SizedBox(height: 12),
          _padded(
            pw.Row(
              children: [
                pw.Expanded(
                  child: _comparisonSectionHeader(
                    label: DecisionCopy.analysisCons,
                    accent: _errorCmp,
                  ),
                ),
                pw.SizedBox(width: 16),
                pw.Expanded(
                  child: _comparisonSectionHeader(
                    label: DecisionCopy.analysisCons,
                    accent: _errorCmp,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          ..._pairedPointRows(
            left: analysis.optionACons,
            right: analysis.optionBCons,
            leftAccent: _errorCmp,
            leftBadgeBg: _softFill,
            rightAccent: _errorCmp,
            rightBadgeBg: _softFill,
            bubbleStyle: false,
            titleSize: 10,
            detailSize: 9,
            gutter: 16,
            cardChrome: true,
          ),
          pw.SizedBox(height: 18),
          _padded(
            _verdictCard(
              title: DecisionCopy.reportVerdictComparison,
              verdictPoints: analysis.verdictPoints,
              sparkles: assets.sparkles,
            ),
          ),
          pw.SizedBox(height: 16),
          _padded(_downloadSection(assets)),
          pw.SizedBox(height: 12),
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
  }) {
    return pw.Container(
      height: 44,
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 1)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            DecisionCopy.reportGeneratedBy,
            style: const pw.TextStyle(color: _textMuted, fontSize: 10),
          ),
          pw.UrlLink(
            destination: DecisionCopy.reportSiteUrl,
            child: pw.Text(
              DecisionCopy.reportSite,
              style: const pw.TextStyle(color: _primary, fontSize: 10),
            ),
          ),
          pw.Spacer(),
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

  static pw.Widget _optionMetaCard({
    required String label,
    required String value,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _softFill,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              color: _primary,
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _columnHeader({
    required String title,
    required PdfColor accent,
    required PdfColor badgeBg,
    required int count,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: accent, width: 2),
        ),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              color: _textPrimary,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(width: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: pw.BoxDecoration(
              color: badgeBg,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              '$count',
              style: pw.TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _comparisonHeading(String heading) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _softFill,
        border: pw.Border.all(color: _border),
      ),
      child: pw.Text(
        heading,
        style: pw.TextStyle(
          color: _headerBg,
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _comparisonSectionHeader({
    required String label,
    required PdfColor accent,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: const pw.BoxDecoration(
        color: _softFill,
        border: pw.Border(
          left: pw.BorderSide(color: _border),
          right: pw.BorderSide(color: _border),
        ),
      ),
      child: pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: accent, width: 2),
          ),
        ),
        child: pw.Row(
          children: [
            pw.Container(
              width: 3,
              height: 14,
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: pw.BorderRadius.circular(2),
              ),
            ),
            pw.SizedBox(width: 10),
            pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                color: _headerBg,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
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
                    pw.Text(
                      point.title,
                      style: pw.TextStyle(
                        color: _textPrimary,
                        fontSize: titleSize,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      point.detail,
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

  static pw.Widget _verdictCard({
    required String title,
    required List<String> verdictPoints,
    required pw.Widget? sparkles,
  }) {
    final items = verdictPoints.isEmpty
        ? const <String>['']
        : verdictPoints;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _softFill,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border),
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
                  color: _textPrimary,
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          for (final point in items)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(top: 4, right: 8),
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
                        color: _textSecondary,
                        fontSize: 10.5,
                        lineSpacing: 3,
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

  static pw.Widget _downloadSection(_ReportAssets assets) {
    return pw.Column(
      children: [
        pw.Text(
          DecisionCopy.reportDownload,
          style: pw.TextStyle(
            color: _headerBg,
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            _storeBadge(
              label: DecisionCopy.reportAppStore,
              icon: assets.apple,
            ),
            pw.SizedBox(width: 12),
            _storeBadge(
              label: DecisionCopy.reportGooglePlay,
              icon: assets.play,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _storeBadge({
    required String label,
    required pw.Widget? icon,
  }) {
    return pw.Container(
      width: 120,
      height: 40,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12),
      decoration: pw.BoxDecoration(
        color: _headerBg,
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            width: 18,
            height: 18,
            alignment: pw.Alignment.center,
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0x1AFFFFFF),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: icon ??
                pw.Text(
                  label[0],
                  style: pw.TextStyle(
                    color: _white,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
          ),
          pw.SizedBox(width: 8),
          pw.Text(
            label,
            style: pw.TextStyle(
              color: _white,
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportAssets {
  const _ReportAssets({
    this.sparkles,
    this.apple,
    this.play,
  });

  final pw.Widget? sparkles;
  final pw.Widget? apple;
  final pw.Widget? play;

  static Future<_ReportAssets> load() async {
    return _ReportAssets(
      sparkles: await _svgIcon('assets/report/sparkles.svg', 14),
      apple: await _svgIcon('assets/report/apple.svg', 12),
      play: await _svgIcon('assets/report/play.svg', 12),
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
}
