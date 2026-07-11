import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/rhythm_element.dart';
import '../models/rhythm_exercise.dart';
import '../widgets/music_staff/music_staff_painter.dart';
import '../widgets/music_staff/staff_geometry.dart' as geometry;
import 'exercise_generation/difficulty_presets.dart';

/// Exports a [RhythmExercise] as a professionally laid out, printable PDF
/// worksheet with Beatter branding.
///
/// The staff itself is rendered by the very same [MusicStaffPainter] used
/// on screen (rasterized at 3× for print sharpness), so paper and screen
/// can never disagree about how an exercise looks. System breaks reuse
/// [geometry.computeSystemBreaks] for the same reason.
class ExercisePdfExporter {
  static const double _pageMargin = 40;
  static const double _systemHeight = 110;
  static const double _rasterScale = 3;

  static const PdfColor _brandOrange = PdfColor.fromInt(0xFFFF7A00);
  static const PdfColor _inkPrimary = PdfColor.fromInt(0xFF2D2D2D);
  static const PdfColor _inkSecondary = PdfColor.fromInt(0xFF666666);

  /// Builds the PDF and hands it to the platform share/download flow
  /// (share sheet on Android/iOS, file download on Web).
  Future<void> export(RhythmExercise exercise) async {
    final bytes = await buildPdf(exercise);
    final safeName = exercise.title.isEmpty
        ? 'esercizio-ritmico'
        : exercise.title.replaceAll(RegExp(r'[^\w\s-]'), '').trim().replaceAll(RegExp(r'\s+'), '-').toLowerCase();
    await Printing.sharePdf(bytes: bytes, filename: '$safeName.pdf');
  }

  /// Assembles the document. Public and side-effect free so tests (or a
  /// future print-preview screen) can inspect the bytes directly.
  Future<Uint8List> buildPdf(RhythmExercise exercise) async {
    final doc = pw.Document(
      title: exercise.title.isEmpty ? 'Esercizio ritmico' : exercise.title,
      author: 'Beatter',
    );

    final logo = await _loadLogo();
    final preset = presetById(exercise.difficultyId);

    final double contentWidth = PdfPageFormat.a4.width - 2 * _pageMargin;

    // Systems are laid out at a "virtual" width holding ~4 measures of 4/4,
    // then scaled uniformly onto the page: engraved-score density without
    // stretching, regardless of page size.
    final double layoutWidth = geometry.staffLeadingX +
        geometry.staffClefWidth +
        geometry.staffTimeSigWidth +
        4 * (geometry.measureWidth('4/4') + geometry.staffMeasureGap);
    final double scale = contentWidth / layoutWidth;

    final systems = geometry.computeSystemBreaks(exercise.measures, layoutWidth);
    final systemImages = <pw.MemoryImage>[];
    for (int s = 0; s < systems.length; s++) {
      final slice = exercise.measures.sublist(
        systems[s].start,
        systems[s].start + systems[s].count,
      );
      systemImages.add(pw.MemoryImage(
        await _renderSystemPng(slice, showTimeSignature: s == 0, width: layoutWidth),
      ));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_pageMargin),
        footer: _buildFooter,
        build: (context) => [
          _buildHeader(logo, exercise, preset),
          pw.SizedBox(height: 18),
          for (final image in systemImages)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Image(
                image,
                width: contentWidth,
                height: _systemHeight * scale,
                fit: pw.BoxFit.fill,
              ),
            ),
        ],
      ),
    );

    return doc.save();
  }

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final data = await rootBundle.load('assets/logos/logo_beatter.png');
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // Missing asset must never block an export — brand text still shows.
      return null;
    }
  }

  pw.Widget _buildHeader(
    pw.MemoryImage? logo,
    RhythmExercise exercise,
    DifficultyPreset preset,
  ) {
    final date = exercise.createdAt;
    final dateLabel = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null) pw.Image(logo, width: 42, height: 42),
            if (logo != null) pw.SizedBox(width: 10),
            pw.Text(
              'Beatter',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: _brandOrange,
              ),
            ),
            pw.Spacer(),
            pw.Text(
              'Rhythm Reading Worksheet',
              style: const pw.TextStyle(fontSize: 10, color: _inkSecondary),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Divider(color: _brandOrange, thickness: 1.5),
        pw.SizedBox(height: 10),
        pw.Text(
          exercise.title.isEmpty ? 'Esercizio ritmico' : exercise.title,
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: _inkPrimary,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            _metaChip('Difficoltà', preset.label),
            _metaChip('Tempo', '${exercise.bpm} BPM'),
            _metaChip('Metro', exercise.timeSignature),
            _metaChip('Battute', '${exercise.measureCount}'),
            _metaChip('Data', dateLabel),
          ],
        ),
      ],
    );
  }

  pw.Widget _metaChip(String label, String value) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(right: 8),
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _inkSecondary, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label: ',
            style: const pw.TextStyle(fontSize: 8, color: _inkSecondary),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _inkPrimary,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Row(
      children: [
        pw.Text(
          'Generato con Beatter',
          style: const pw.TextStyle(fontSize: 8, color: _inkSecondary),
        ),
        pw.Spacer(),
        pw.Text(
          'Pagina ${context.pageNumber} di ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: _inkSecondary),
        ),
      ],
    );
  }

  /// Rasterizes one staff system through [MusicStaffPainter] at
  /// [_rasterScale]× so it stays crisp at print resolution.
  Future<Uint8List> _renderSystemPng(
    List<RhythmMeasure> slice, {
    required bool showTimeSignature,
    required double width,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(_rasterScale);

    MusicStaffPainter(
      measures: slice,
      activeMeasureIndex: -1,
      activeElementIndex: -1,
      showTimeSignature: showTimeSignature,
    ).paint(canvas, Size(width, _systemHeight));

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (width * _rasterScale).ceil(),
      (_systemHeight * _rasterScale).ceil(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }
}
