import 'dart:math' as math;
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
  static const _bandHeight = 44.0;
  static const _pageBandGap = 6.0;
  /// Keeps header and footer out of the printer's unprintable edge.
  static const _printMargin = 36.0;

  static Future<Uint8List> build(
    DecisionAnalysis analysis, {
    String? obstacle,
    String? timing,
    DateTime? generatedAt,
    Locale? locale,
  }) async {
    final assets = await _ReportAssets.load();
    final when = generatedAt ?? DateTime.now();
    final resolvedLocale = locale ?? PlatformDispatcher.instance.locale;
    final dateLabel = await _formatFooterDate(when, resolvedLocale);

    final doc = pw.Document(
      title: DecisionCopy.reportComparisonSubtitle,
      author: 'Twiffel',
    );

    _addComparisonPages(
      doc,
      analysis,
      assets,
      dateLabel,
      _pageFormatFor(resolvedLocale),
      obstacle: obstacle,
      timing: timing,
    );

    return doc.save();
  }

  /// Android "Save as PDF" uses Letter in US-style locales, A4 elsewhere.
  /// An A4 page on Letter paper sits top-left with a wide right gap.
  static PdfPageFormat _pageFormatFor(Locale locale) {
    final country = locale.countryCode?.toUpperCase();
    if (country == 'US' || country == 'CA' || country == 'MX') {
      return PdfPageFormat.letter;
    }
    if ((country == null || country.isEmpty) &&
        locale.languageCode.toLowerCase() == 'en') {
      return PdfPageFormat.letter;
    }
    return PdfPageFormat.a4;
  }

  /// Share filename: `Twiffel results <date> <time>.pdf`.
  ///
  /// Date and time use the device locale (or [locale] when provided). Characters
  /// that are illegal in file names (`/` `:` and similar) are replaced so Save
  /// and Forward keep a readable name.
  static Future<String> filenameFor({
    DateTime? at,
    Locale? locale,
  }) async {
    final parts = await _shareDateTimeParts(at: at, locale: locale);
    final raw =
        '${DecisionCopy.analysisShareFilenamePrefix} ${parts.date} ${parts.time}';
    return '${_fileSafe(raw)}.pdf';
  }

  /// Email subject when the user picks Mail from the share sheet.
  static String shareSubject() => DecisionCopy.analysisShareSubject;

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

  static void _addComparisonPages(
    pw.Document doc,
    DecisionAnalysis analysis,
    _ReportAssets assets,
    String dateLabel,
    PdfPageFormat pageFormat, {
    String? obstacle,
    String? timing,
  }) {
    final optionA = analysis.optionA.trim().isNotEmpty
        ? analysis.optionA.trim()
        : DecisionCopy.analysisOptionALabel;
    final optionB = analysis.optionB.trim().isNotEmpty
        ? analysis.optionB.trim()
        : DecisionCopy.analysisOptionBLabel;
    final score = AnalysisScore.fromAnalysis(analysis);
    final preferA = score.leansPrimary;
    final preferB = !score.leansPrimary;
    _layoutFormat = pageFormat;

    doc.addPage(
      pw.Page(
        pageFormat: _layoutFormat,
        margin: const pw.EdgeInsets.all(_printMargin),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _headerWithGap(
                subtitle: DecisionCopy.reportComparisonSubtitle,
              ),
              _vsBar(optionA: optionA, optionB: optionB),
              pw.SizedBox(height: 8),
              if ((obstacle ?? '').trim().isNotEmpty ||
                  (timing ?? '').trim().isNotEmpty) ...[
                _padded(
                  _parametersCard(
                    obstacle: obstacle?.trim() ?? '',
                    timing: timing?.trim() ?? '',
                  ),
                ),
                pw.SizedBox(height: 8),
              ],
              _padded(
                _verdictCard(
                  title: DecisionCopy.reportVerdictComparison,
                  verdictPoints: analysis.verdictPoints,
                  strength: score.strength,
                  leansPrimary: score.leansPrimary,
                  favoredName: score.favoredName,
                ),
              ),
              pw.SizedBox(height: 8),
              _padded(
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: _favorCard(
                        title: optionA,
                        letter: 'A',
                        badgeColor: _headerBg,
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
                        letter: 'B',
                        badgeColor: _primary,
                        percent: score.secondaryFavorPercent,
                        preferred: preferB,
                        pros: analysis.optionBPros,
                        cons: analysis.optionBCons,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Spacer(),
              _footerWithGap(
                context: context,
                dateLabel: dateLabel,
                assets: assets,
              ),
            ],
          );
        },
      ),
    );
    _addComparisonSection(
      doc,
      assets: assets,
      dateLabel: dateLabel,
      children: [
        pw.SizedBox(height: 16),
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
          bubbleStyle: true,
          titleSize: 10,
          detailSize: 9,
          gutter: 16,
        ),
        ..._sectionEndImage(assets.cover),
      ],
    );
    _addComparisonSection(
      doc,
      assets: assets,
      dateLabel: dateLabel,
      children: [
        pw.SizedBox(height: 16),
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
          bubbleStyle: true,
          titleSize: 10,
          detailSize: 9,
          gutter: 16,
        ),
        ..._sectionEndImage(assets.coverCons),
      ],
    );
  }

  static void _addComparisonSection(
    pw.Document doc, {
    required _ReportAssets assets,
    required String dateLabel,
    required List<pw.Widget> children,
  }) {
    doc.addPage(
      pw.MultiPage(
        pageFormat: _layoutFormat,
        margin: const pw.EdgeInsets.all(_printMargin),
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        header: (context) => _headerWithGap(
          subtitle: DecisionCopy.reportComparisonSubtitle,
        ),
        footer: (context) => _footerWithGap(
          context: context,
          dateLabel: dateLabel,
          assets: assets,
        ),
        build: (context) => children,
      ),
    );
  }

  static PdfPageFormat _layoutFormat = PdfPageFormat.letter;
  static const _pageGutter = 28.0;

  static double get _contentWidth =>
      _layoutFormat.width - _printMargin * 2 - _pageGutter * 2;

  static pw.Widget _padded(pw.Widget child) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: _pageGutter),
      child: pw.SizedBox(width: _contentWidth, child: child),
    );
  }

  /// Fills leftover page space and centers the illustration in that blank.
  static List<pw.Widget> _sectionEndImage(pw.ImageProvider? image) {
    if (image == null) return const [];
    return [
      pw.Expanded(
        child: pw.Align(
          alignment: pw.Alignment.center,
          child: pw.ConstrainedBox(
            constraints: pw.BoxConstraints(
              maxWidth: _contentWidth,
              maxHeight: 320,
            ),
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      ),
    ];
  }

  static pw.Widget _headerWithGap({
    required String subtitle,
  }) {
    return pw.Column(
      children: [
        _headerBand(subtitle: subtitle),
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
  }) {
    return pw.Container(
      height: _bandHeight,
      width: double.infinity,
      color: _headerBg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          _brandMark(size: 20),
          pw.SizedBox(width: 6),
          pw.Text(
            'Twiffel',
            style: pw.TextStyle(
              color: _white,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Spacer(),
          pw.Text(
            subtitle.toUpperCase(),
            style: pw.TextStyle(
              color: _primarySoft,
              fontSize: 9,
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
      height: 56,
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 1)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
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
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                dateLabel,
                style: const pw.TextStyle(color: _textMuted, fontSize: 8),
              ),
              pw.SizedBox(width: 10),
              pw.Container(width: 1, height: 10, color: _border),
              pw.SizedBox(width: 10),
              pw.Text(
                'Page ${context.pageNumber} of ${context.pagesCount}',
                style: pw.TextStyle(
                  color: _textSecondary,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _storeBadge(
                artwork: assets.appStore,
                url: DecisionCopy.reportAppStoreUrl,
                fallbackLabel: DecisionCopy.reportAppStore,
              ),
              pw.SizedBox(width: 6),
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
                    accent: leftAccent,
                    badgeBg: leftBadgeBg,
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
                    accent: rightAccent,
                    badgeBg: rightBadgeBg,
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

  /// One to five tinted stars, same log remap as the Detailed Score.
  static pw.Widget _weightStarBadge({
    required int weight,
    required PdfColor accent,
    required PdfColor fill,
    required double size,
  }) {
    final count = weightSignCount(weight);
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(4, 1.5, 3, 1.5),
      decoration: pw.BoxDecoration(
        color: fill,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++) _starIcon(accent, size),
        ],
      ),
    );
  }

  static pw.Widget _starIcon(PdfColor color, double size) {
    return pw.SizedBox(
      width: size,
      height: size,
      child: pw.CustomPaint(
        size: PdfPoint(size, size),
        painter: (canvas, bounds) {
          final cx = bounds.x / 2;
          final cy = bounds.y / 2;
          final outer = math.min(bounds.x, bounds.y) / 2;
          final inner = outer * 0.42;
          for (var i = 0; i < 10; i++) {
            final radius = i.isEven ? outer : inner;
            final angle = -math.pi / 2 + i * math.pi / 5;
            final x = cx + radius * math.cos(angle);
            final y = cy + radius * math.sin(angle);
            if (i == 0) {
              canvas.moveTo(x, y);
            } else {
              canvas.lineTo(x, y);
            }
          }
          canvas
            ..closePath()
            ..setFillColor(color)
            ..fillPath();
        },
      ),
    );
  }

  static pw.Widget _pointCell({
    required AnalysisPoint? point,
    required PdfColor accent,
    required PdfColor badgeBg,
    required double titleSize,
    required double detailSize,
    required bool cardChrome,
    required bool isLast,
  }) {
    final body = point == null
        ? pw.SizedBox()
        : pw.Column(
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
                  _weightStarBadge(
                    weight: point.weight,
                    accent: accent,
                    fill: badgeBg,
                    size: titleSize,
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

  static pw.Widget _optionBadge({
    required String letter,
    required PdfColor fill,
    double size = 16,
    bool prominent = false,
  }) {
    final badge = pw.Container(
      width: size,
      height: size,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: fill,
        borderRadius: pw.BorderRadius.circular(size / 2),
      ),
      child: pw.Text(
        letter,
        style: pw.TextStyle(
          color: _white,
          fontSize: size * 0.5,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
    if (!prominent) return badge;
    return pw.Container(
      padding: const pw.EdgeInsets.all(2.5),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular((size + 5) / 2),
        border: pw.Border.all(color: fill, width: 1.4),
      ),
      child: badge,
    );
  }

  /// pdf 3.13 has no [pw.TextOverflow.ellipsis]; approximate with clip + "...".
  static String _fitEllipsis(String text, double maxWidth, double fontSize) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    final maxChars = math.max(4, (maxWidth / (fontSize * 0.52)).floor());
    if (trimmed.length <= maxChars) return trimmed;
    final cut = math.max(1, maxChars - 3);
    return '${trimmed.substring(0, cut).trimRight()}...';
  }

  static pw.Widget _ellipsisLine(
    String text, {
    double fontSize = 10,
    pw.FontWeight? weight,
    PdfColor? color,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.LayoutBuilder(
      builder: (context, constraints) {
        final raw = constraints?.maxWidth;
        final maxW =
            (raw == null || !raw.isFinite || raw <= 0) ? 200.0 : raw;
        return pw.Text(
          _fitEllipsis(text, maxW, fontSize),
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          textAlign: align,
          style: pw.TextStyle(
            color: color ?? _textPrimary,
            fontSize: fontSize,
            fontWeight: weight,
          ),
        );
      },
    );
  }

  static pw.Widget _optionLabelRow({
    required String letter,
    required String name,
    required PdfColor fill,
    double badgeSize = 16,
    double fontSize = 10,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        _optionBadge(letter: letter, fill: fill, size: badgeSize),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: _ellipsisLine(
            name,
            fontSize: fontSize,
            weight: pw.FontWeight.bold,
            align: align,
          ),
        ),
      ],
    );
  }

  static pw.Widget _optionWrapRow({
    required String letter,
    required String name,
    required PdfColor fill,
    double badgeSize = 24,
    bool prominent = true,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _optionBadge(
          letter: letter,
          fill: fill,
          size: badgeSize,
          prominent: prominent,
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              name,
              style: pw.TextStyle(
                color: _textPrimary,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                lineSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static pw.Widget _vsBar({
    required String optionA,
    required String optionB,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      decoration: const pw.BoxDecoration(
        color: _softFill,
        border: pw.Border(bottom: pw.BorderSide(color: _border)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _optionWrapRow(
              letter: 'A',
              name: optionA,
              fill: _headerBg,
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Text(
              DecisionCopy.analysisVsWord.toLowerCase(),
              style: const pw.TextStyle(color: _textMuted, fontSize: 11),
            ),
          ),
          pw.Expanded(
            child: _optionWrapRow(
              letter: 'B',
              name: optionB,
              fill: _primary,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _favorCard({
    required String title,
    required String letter,
    required PdfColor badgeColor,
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
          pw.SizedBox(height: 6),
          for (var i = 0; i < points.length && i < 5; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 5),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      points[i].tagline,
                      maxLines: 2,
                      style: const pw.TextStyle(
                        color: _textPrimary,
                        fontSize: 8,
                        lineSpacing: 2,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  _weightStarBadge(
                    weight: points[i].weight,
                    accent: accent,
                    fill: accent == _error ? _errorSoft : _successSoft,
                    size: 7,
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _optionLabelRow(
            letter: letter,
            name: title,
            fill: badgeColor,
            badgeSize: 16,
            fontSize: 10,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            DecisionCopy.reportFavor,
            style: const pw.TextStyle(color: _textMuted, fontSize: 8),
          ),
          pw.SizedBox(height: 8),
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
            pw.SizedBox(height: 10),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: list(DecisionCopy.analysisPros, pros, _success)),
                pw.SizedBox(width: 8),
                pw.Expanded(child: list(DecisionCopy.analysisCons, cons, _error)),
              ],
            ),
          ] else if (showPros) ...[
            pw.SizedBox(height: 10),
            list(DecisionCopy.analysisPros, pros, _success),
          ] else if (showCons) ...[
            pw.SizedBox(height: 10),
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

  static pw.Widget _detailBanner(String title, PdfColor accent, PdfColor fill) {
    return pw.Container(
      width: double.infinity,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: fill,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: accent, width: 0.6),
      ),
      child: pw.Text(
        title.toUpperCase(),
        textAlign: pw.TextAlign.center,
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
          child: _optionLabelRow(
            letter: 'A',
            name: optionA,
            fill: _headerBg,
            badgeSize: 16,
            fontSize: 11,
          ),
        ),
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: _optionLabelRow(
            letter: 'B',
            name: optionB,
            fill: _primary,
            badgeSize: 16,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  static pw.Widget _parametersCard({
    required String obstacle,
    required String timing,
  }) {
    final items = <({String label, String value})>[
      if (obstacle.isNotEmpty)
        (
          label: DecisionCopy.reportConsiderationLabel,
          value: obstacle,
        ),
      if (timing.isNotEmpty)
        (label: DecisionCopy.reportTimingLabel, value: timing),
    ];

    pw.Widget cell(({String label, String value}) item) {
      return pw.Column(
        children: [
          pw.Text(
            item.label.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: _textMuted,
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            item.value,
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(
              color: _textPrimary,
              fontSize: 9,
              lineSpacing: 2,
            ),
          ),
        ],
      );
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _softFill,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _border),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            DecisionCopy.reportParametersHeading.toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              color: _textSecondary,
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) pw.SizedBox(width: 12),
                pw.Expanded(child: cell(items[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _verdictHeadline({
    required LeanStrength strength,
    required bool leansPrimary,
    required String favoredName,
  }) {
    final style = pw.TextStyle(
      color: _textPrimary,
      fontSize: 11,
      fontWeight: pw.FontWeight.bold,
    );
    if (strength == LeanStrength.tooClose) {
      return pw.Text(DecisionCopy.analysisLeanTooClose, style: style);
    }
    final prefix = strength == LeanStrength.clear
        ? DecisionCopy.reportLeanClearToOption
        : DecisionCopy.reportLeanSlightToOption;
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('$prefix ', style: style),
        _optionBadge(
          letter: leansPrimary ? 'A' : 'B',
          fill: leansPrimary ? _headerBg : _primary,
          size: 16,
        ),
        pw.SizedBox(width: 6),
        pw.Expanded(
          child: _ellipsisLine(
            favoredName,
            fontSize: 11,
            weight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  static pw.Widget _verdictCard({
    required String title,
    required List<String> verdictPoints,
    required LeanStrength strength,
    required bool leansPrimary,
    required String favoredName,
  }) {
    final items = verdictPoints.isEmpty ? const <String>[''] : verdictPoints;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _verdictFill,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _verdictBorder),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              color: _primary,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          _verdictHeadline(
            strength: strength,
            leansPrimary: leansPrimary,
            favoredName: favoredName,
          ),
          pw.SizedBox(height: 10),
          for (final point in items)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
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
    this.appStore,
    this.googlePlay,
    this.cover,
    this.coverCons,
  });

  final pw.Widget? appStore;
  final pw.Widget? googlePlay;
  final pw.ImageProvider? cover;
  final pw.ImageProvider? coverCons;

  /// Footer band is 44pt, so badges stay a bit under that height.
  static const _badgeHeight = 22.0;
  static const _appStoreWidth = _badgeHeight * 119.66407 / 40;
  static const _playWidth = _badgeHeight * 239 / 70.9;

  static Future<_ReportAssets> load() async {
    return _ReportAssets(
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
      cover: await _jpeg('assets/report/cover.jpg'),
      coverCons: await _jpeg('assets/report/cover-cons.jpg'),
    );
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

  static Future<pw.ImageProvider?> _jpeg(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }
}
