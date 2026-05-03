import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:barcode/barcode.dart' show BarcodeQRCorrectionLevel;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/icon_catalog.dart';
import '../../models/tracked_object.dart';
import '../../services/qr_service.dart';

/// Generates printable PDFs of object QR codes — either a sheet of
/// many (3 cols × 4 rows max per A4 page) for bulk setup, or a
/// single object centered on its own page.
///
///
/// Center logo uses real Material icons. We render each icon to a
/// PNG via Flutter's painting engine (TextPainter + Picture.toImage —
/// the same path Flutter's Icon widget uses internally) and embed
/// the PNG via `pw.Image`. No font asset bundling needed.
class QrExportService {
  QrExportService();

  final _qr = QrService();

  /// Bulk export — every object on a printable A4 sheet.
  /// Layout: 3 columns × max 4 rows per page, auto-paginated.
  Future<void> exportAll(List<TrackedObject> objects) async {
    if (objects.isEmpty) {
      throw StateError('No objects to export');
    }

    // Pre-render icon PNGs on the main isolate. Picture.toImage()
    // requires the Flutter framework, so we can't do this lazily
    // inside the synchronous PDF build callback.
    final iconPngs = <String, Uint8List>{};
    for (final obj in objects) {
      iconPngs[obj.id] = await _iconToPng(iconFor(obj.iconKey));
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (ctx) => [
          pw.Text(
            'Shift My OCD — QR codes',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Cut along the borders and stick each one on its object.',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),

          // Grid: rows of 3 items.
          for (var i = 0; i < objects.length; i += 3)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  for (var j = 0; j < 3; j++) ...[
                    pw.Expanded(
                      child: i + j < objects.length
                          ? _qrCard(
                              objects[i + j],
                              iconPngs[objects[i + j].id]!,
                            )
                          : pw.SizedBox(),
                    ),
                    if (j < 2) pw.SizedBox(width: 8),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'shift-my-ocd-qr-codes.pdf',
    );
  }

  /// Single object — centered, larger QR, name + description above.
  Future<void> exportSingle(TrackedObject object) async {
    final iconPng = await _iconToPng(iconFor(object.iconKey));
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.SizedBox(height: 80),
            pw.Text(
              object.name,
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (object.description.isNotEmpty) ...[
              pw.SizedBox(height: 12),
              pw.Container(
                constraints: const pw.BoxConstraints(maxWidth: 400),
                child: pw.Text(
                  object.description,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 14,
                    color: PdfColors.grey700,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            ],
            pw.SizedBox(height: 50),
            _qrWithLogo(
              data: _qr.encode(object.id),
              size: 280,
              iconPng: iconPng,
            ),
            pw.SizedBox(height: 40),
            pw.Text(
              'Scan whenever you physically check this.',
              style: pw.TextStyle(
                fontSize: 12,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: 'qr-${_safeFilename(object.name)}.pdf',
    );
  }

  // --- internal building blocks --------------------------------------

  pw.Widget _qrCard(TrackedObject obj, Uint8List iconPng) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        children: [
          _qrWithLogo(
            data: _qr.encode(obj.id),
            size: 130,
            iconPng: iconPng,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            obj.name,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ],
      ),
    );
  }

  pw.Widget _qrWithLogo({
    required String data,
    required double size,
    required Uint8List iconPng,
  }) {
    final logoOuterSize = size * 0.22; // white halo
    final logoInnerSize = size * 0.18; // icon image

    return pw.Stack(
      alignment: pw.Alignment.center,
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(
            errorCorrectLevel: BarcodeQRCorrectionLevel.high,
          ),
          data: data,
          width: size,
          height: size,
          drawText: false,
        ),
        pw.Container(
          width: logoOuterSize,
          height: logoOuterSize,
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(4),
          ),
        ),
        pw.Image(
          pw.MemoryImage(iconPng),
          width: logoInnerSize,
          height: logoInnerSize,
        ),
      ],
    );
  }

  /// Renders a Material icon to a PNG via Flutter's painting engine.
  ///
  ///
  /// Output: `logicalSize × logicalSize` rendered at 3x DPR for sharp
  /// printing, with a rounded colored background and a centered white
  /// glyph. Returned as PNG bytes for `pw.MemoryImage`.
  static Future<Uint8List> _iconToPng(IconData icon) async {
    const logicalSize = 60.0;
    const dpr = 3.0;
    final pixelSize = (logicalSize * dpr).round();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);

    // Rounded colored background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, logicalSize, logicalSize),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF1976D2), // matches PdfColors.blue700
    );

    // Resolve fontFamily — packaged fonts need a "packages/<pkg>/<family>"
    // prefix instead of using TextStyle.package, which keeps us compatible
    // across Flutter SDK versions where the parameter has shifted.
    final family = icon.fontFamily;
    final pkg = icon.fontPackage;
    final resolvedFamily =
        (family != null && pkg != null) ? 'packages/$pkg/$family' : family;

    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: resolvedFamily,
          fontSize: logicalSize * 0.7,
          color: Colors.white,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(
        (logicalSize - tp.width) / 2,
        (logicalSize - tp.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(pixelSize, pixelSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    return bytes!.buffer.asUint8List();
  }

  static String _safeFilename(String name) {
    final cleaned = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return cleaned.isEmpty ? 'object' : cleaned;
  }
}