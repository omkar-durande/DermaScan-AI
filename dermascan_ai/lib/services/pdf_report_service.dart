import 'package:flutter/material.dart' show BuildContext;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/scan_result.dart';
import '../models/user_model.dart';
import '../constants/disease_data.dart';

/// Service to generate and share a DermaScan PDF report
class PdfReportService {
  PdfReportService._();

  // ── Brand colours ────────────────────────────────────────────────
  static const _primary = PdfColor.fromInt(0xFF6C5CE7);
  static const _accent  = PdfColor.fromInt(0xFF00CEC9);
  static const _danger  = PdfColor.fromInt(0xFFE17055);
  static const _warning = PdfColor.fromInt(0xFFFDCB6E);
  static const _success = PdfColor.fromInt(0xFF00B894);
  static const _bg      = PdfColor.fromInt(0xFFF8F9FA);
  static const _surface = PdfColors.white;
  static const _text    = PdfColor.fromInt(0xFF2D3436);
  static const _textSec = PdfColor.fromInt(0xFF636E72);
  static const _border  = PdfColor.fromInt(0xFFDFE6E9);

  // ── Public entry point ────────────────────────────────────────────

  static Future<void> generateAndShare({
    required List<ScanResult> scans,
    required UserModel? user,
    required BuildContext context,
  }) async {
    final doc = pw.Document(
      title: 'DermaScan AI - Medical Report',
      author: 'DermaScan AI',
    );

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(color: _bg),
          ),
        ),
        header: (ctx) => _buildHeader(ctx),
        footer: (ctx) => _buildFooter(ctx),
        build: (ctx) => [
          _buildPatientSection(user),
          pw.SizedBox(height: 14),
          _buildStatsRow(scans),
          pw.SizedBox(height: 18),
          _buildSectionTitle('Scan History (${scans.length} records)'),
          pw.SizedBox(height: 8),
          ...scans.asMap().entries.map((e) => _buildScanCard(e.value, e.key + 1)),
          pw.SizedBox(height: 16),
          _buildDisclaimer(),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          'DermaScan_Report_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
    );
  }

  // ── Header ───────────────────────────────────────────────────────

  static pw.Widget _buildHeader(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const pw.BoxDecoration(
        gradient: pw.LinearGradient(
          colors: [_primary, _accent],
          begin: pw.Alignment.centerLeft,
          end: pw.Alignment.centerRight,
        ),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'DermaScan AI',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Medical Skin Analysis Report',
                style: const pw.TextStyle(
                  color: PdfColor(1, 1, 1, 0.75),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          pw.Text(
            'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(
              color: PdfColor(1, 1, 1, 0.75),
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  // ── Footer ───────────────────────────────────────────────────────

  static pw.Widget _buildFooter(pw.Context ctx) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _border, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated: ${DateFormat('MMM dd, yyyy  hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(color: _textSec, fontSize: 8),
          ),
          pw.Text(
            'For informational purposes only. Consult a dermatologist.',
            style: const pw.TextStyle(color: _textSec, fontSize: 8),
          ),
        ],
      ),
    );
  }

  // ── Patient section ──────────────────────────────────────────────

  static pw.Widget _buildPatientSection(UserModel? user) {
    final name = user?.displayName ?? 'Unknown Patient';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _border, width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Avatar circle
          pw.Container(
            width: 44,
            height: 44,
            decoration: const pw.BoxDecoration(
              color: _primary,
              shape: pw.BoxShape.circle,
            ),
            child: pw.Center(
              child: pw.Text(
                initial,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.SizedBox(width: 14),
          // Patient details
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  name,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _text,
                  ),
                ),
                if (user?.email != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    user!.email!,
                    style: const pw.TextStyle(fontSize: 9, color: _textSec),
                  ),
                ],
                if (user?.phone != null) ...[
                  pw.SizedBox(height: 2),
                  pw.Text(
                    user!.phone!,
                    style: const pw.TextStyle(fontSize: 9, color: _textSec),
                  ),
                ],
              ],
            ),
          ),
          // Date chip
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _bg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: _border, width: 0.5),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'Report Date',
                  style: const pw.TextStyle(fontSize: 7, color: _textSec),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  DateFormat('MMM dd, yyyy').format(DateTime.now()),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: _text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ────────────────────────────────────────────────────

  static pw.Widget _buildStatsRow(List<ScanResult> scans) {
    final total = scans.length;
    final avg = scans.isEmpty
        ? 0.0
        : scans.map((s) => s.confidence).reduce((a, b) => a + b) / scans.length;
    final urgent = scans.where((s) => s.isUrgent).length;
    final last = scans.isNotEmpty
        ? DateFormat('MMM dd').format(scans.first.timestamp)
        : 'N/A';

    return pw.Row(
      children: [
        _buildStatBox('Total Scans', '$total', _primary),
        pw.SizedBox(width: 8),
        _buildStatBox('Avg Confidence', '${(avg * 100).toStringAsFixed(0)}%', _accent),
        pw.SizedBox(width: 8),
        _buildStatBox('Urgent Cases', '$urgent', urgent > 0 ? _danger : _success),
        pw.SizedBox(width: 8),
        _buildStatBox('Last Scan', last, _primary),
      ],
    );
  }

  static pw.Widget _buildStatBox(String label, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: pw.BoxDecoration(
          color: _surface,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          border: pw.Border.all(color: _border, width: 0.5),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: _textSec),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Section title ────────────────────────────────────────────────

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 16,
          decoration: const pw.BoxDecoration(
            color: _primary,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: _text,
          ),
        ),
      ],
    );
  }

  // ── Scan card ────────────────────────────────────────────────────

  static pw.Widget _buildScanCard(ScanResult scan, int index) {
    final disease     = DiseaseData.getDisease(scan.disease);
    final urgency     = scan.severity.toLowerCase();
    final urgencyColor = (urgency == 'critical' || urgency == 'high')
        ? _danger
        : urgency == 'medium'
            ? _warning
            : _success;
    final pct        = (scan.confidence * 100).toStringAsFixed(1);
    final barColor   = scan.confidence >= 0.7 ? _success : _warning;
    // Width of confidence bar in points (max ~475pt for A4 content area minus padding)
    const maxBar     = 447.0;
    final filledW    = maxBar * scan.confidence;

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _surface,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _border, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // ── Top row: index + name + badges ──────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Index circle
              pw.Container(
                width: 20,
                height: 20,
                decoration: const pw.BoxDecoration(
                  color: _primary,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    '$index',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      scan.fullName,
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Code: ${scan.disease}   |   ${DateFormat('dd MMM yyyy, hh:mm a').format(scan.timestamp)}',
                      style: const pw.TextStyle(fontSize: 8, color: _textSec),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 8),
              // Severity badge
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: urgencyColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                ),
                child: pw.Text(
                  urgency.toUpperCase(),
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              // Confidence badge
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: _bg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
                  border: pw.Border.all(color: _border, width: 0.5),
                ),
                child: pw.Text(
                  '$pct%',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: barColor,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // ── Confidence bar (background then filled layer) ────────
          pw.Stack(
            children: [
              pw.Container(
                height: 5,
                decoration: const pw.BoxDecoration(
                  color: _bg,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
              ),
              pw.Container(
                width: filledW,
                height: 5,
                decoration: pw.BoxDecoration(
                  color: barColor,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),

          // ── Disease description ──────────────────────────────────
          if (disease != null)
            pw.Text(
              disease['description'] as String,
              style: const pw.TextStyle(fontSize: 9, color: _textSec),
            ),

          // ── Urgent warning ───────────────────────────────────────
          if (scan.isUrgent) ...[
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: const PdfColor(0.99, 0.95, 0.94),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: _danger, width: 0.5),
              ),
              child: pw.Text(
                'URGENT: This condition requires immediate medical attention. '
                'Please consult a dermatologist as soon as possible.',
                style: const pw.TextStyle(fontSize: 8, color: _danger),
              ),
            ),
          ],

          pw.SizedBox(height: 8),

          // ── All probabilities ────────────────────────────────────
          pw.Text(
            'All Probabilities:',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Wrap(
            spacing: 5,
            runSpacing: 4,
            children: scan.sortedScores.take(7).map((e) {
              final isTop = e.key == scan.disease;
              final prob  = (e.value * 100).toStringAsFixed(1);
              return pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: isTop ? _primary : _bg,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(
                    color: isTop ? _primary : _border,
                    width: 0.5,
                  ),
                ),
                child: pw.Text(
                  '${e.key}: $prob%',
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    color: isTop ? PdfColors.white : _textSec,
                    fontWeight: isTop ? pw.FontWeight.bold : pw.FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Disclaimer ───────────────────────────────────────────────────

  static pw.Widget _buildDisclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: const PdfColor(1.0, 0.98, 0.90),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
        border: pw.Border.all(color: _warning, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'MEDICAL DISCLAIMER',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: _text,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'This report is generated by DermaScan AI for informational purposes only. '
            'It does NOT constitute medical advice, diagnosis, or treatment. '
            'AI-based skin analysis may not be 100% accurate. '
            'Always consult a qualified dermatologist or healthcare professional '
            'for proper diagnosis and treatment. '
            'Do not use this report as a substitute for professional medical advice.',
            style: const pw.TextStyle(fontSize: 8, color: _textSec),
          ),
        ],
      ),
    );
  }
}
