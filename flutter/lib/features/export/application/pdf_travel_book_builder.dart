import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/pdf_export_models.dart';

final class PdfTravelBookBuilder {
  const PdfTravelBookBuilder();

  Future<PdfExportResult> build({
    required JourneyExportData data,
    required PdfExportOptions options,
    PdfImageResolver? resolveImage,
  }) async {
    final document = pw.Document();
    var pageCount = 0;

    pw.MemoryImage? imageFor(Uint8List? bytes) =>
        bytes == null || bytes.isEmpty ? null : pw.MemoryImage(bytes);

    if (options.includeCover) {
      final coverBytes = data.coverPhotoUri == null || resolveImage == null
          ? null
          : await resolveImage(data.coverPhotoUri!);
      final coverImage = imageFor(coverBytes);

      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Container(
            padding: const pw.EdgeInsets.all(44),
            decoration: pw.BoxDecoration(
              gradient: pw.LinearGradient(
                colors: _styleColors(options.style),
                begin: pw.Alignment.topLeft,
                end: pw.Alignment.bottomRight,
              ),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                if (coverImage != null)
                  pw.Expanded(
                    child: pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 28),
                      child: pw.Image(
                        coverImage,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  ),
                pw.Text(
                  data.title.trim().isEmpty ? data.destination : data.title,
                  style: pw.TextStyle(
                    fontSize: 34,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  data.destination +
                      (data.country.trim().isEmpty
                          ? ''
                          : ' • ' + data.country),
                  style: const pw.TextStyle(
                    fontSize: 17,
                    color: PdfColors.white,
                  ),
                ),
                if (options.includeDates) ...[
                  pw.SizedBox(height: 10),
                  pw.Text(
                    data.startDate + ' — ' + data.endDate,
                    style: const pw.TextStyle(
                      fontSize: 13,
                      color: PdfColors.white,
                    ),
                  ),
                ],
                pw.SizedBox(height: 26),
                pw.Text(
                  'WONDERLOG',
                  style: pw.TextStyle(
                    fontSize: 11,
                    letterSpacing: 3,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      pageCount++;
    }

    if (options.includeJourneyDescription &&
        data.description.trim().isNotEmpty) {
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => _textPage(
            title: data.destination,
            body: data.description,
            footer: options.includePageNumbers
                ? (pageCount + 1).toString()
                : null,
          ),
        ),
      );
      pageCount++;
    }

    if (options.includeMemories) {
      for (final memory in data.memories) {
        pw.MemoryImage? hero;
        if (resolveImage != null && memory.photoUris.isNotEmpty) {
          hero = imageFor(await resolveImage(memory.photoUris.first));
        }

        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) => pw.Padding(
              padding: const pw.EdgeInsets.all(44),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (hero != null) ...[
                    pw.SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: pw.Image(hero, fit: pw.BoxFit.cover),
                    ),
                    pw.SizedBox(height: 24),
                  ],
                  pw.Text(
                    memory.title,
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (options.includeDates) ...[
                    pw.SizedBox(height: 8),
                    pw.Text(memory.date),
                  ],
                  if (options.includeLocations &&
                      (memory.location ?? '').trim().isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text('📍 ' + memory.location!),
                  ],
                  if ((memory.mood ?? '').trim().isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(memory.mood!),
                  ],
                  pw.SizedBox(height: 20),
                  pw.Text(
                    memory.journalText,
                    style: const pw.TextStyle(
                      fontSize: 12,
                      lineSpacing: 5,
                    ),
                  ),
                  pw.Spacer(),
                  if (options.includePageNumbers)
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text((pageCount + 1).toString()),
                    ),
                ],
              ),
            ),
          ),
        );
        pageCount++;
      }
    }

    if (options.includeAlbumPhotos && data.photos.isNotEmpty) {
      for (var start = 0; start < data.photos.length; start += 4) {
        final end = (start + 4) > data.photos.length
            ? data.photos.length
            : start + 4;
        final batch = data.photos.sublist(start, end);
        final resolved = <String, pw.MemoryImage?>{};

        if (resolveImage != null) {
          for (final photo in batch) {
            resolved[photo.uri] = imageFor(await resolveImage(photo.uri));
          }
        }

        document.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (context) => pw.Padding(
              padding: const pw.EdgeInsets.all(36),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Album',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 18),
                  pw.Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: batch.map((photo) {
                      final image = resolved[photo.uri];
                      return pw.Container(
                        width: 245,
                        height: 300,
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: image == null
                                  ? pw.Container(
                                      color: PdfColors.grey200,
                                      alignment: pw.Alignment.center,
                                      child: pw.Text('Photo'),
                                    )
                                  : pw.Image(image, fit: pw.BoxFit.cover),
                            ),
                            if ((photo.caption ?? '').trim().isNotEmpty) ...[
                              pw.SizedBox(height: 6),
                              pw.Text(
                                photo.caption!,
                                maxLines: 2,
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(growable: false),
                  ),
                  pw.Spacer(),
                  if (options.includePageNumbers)
                    pw.Align(
                      alignment: pw.Alignment.centerRight,
                      child: pw.Text((pageCount + 1).toString()),
                    ),
                ],
              ),
            ),
          ),
        );
        pageCount++;
      }
    }

    final bytes = await document.save();
    return PdfExportResult(
      bytes: bytes,
      fileName: _safeFileName(data),
      pageCount: pageCount,
    );
  }

  pw.Widget _textPage({
    required String title,
    required String body,
    String? footer,
  }) =>
      pw.Padding(
        padding: const pw.EdgeInsets.all(44),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 28,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              body,
              style: const pw.TextStyle(
                fontSize: 12,
                lineSpacing: 5,
              ),
            ),
            pw.Spacer(),
            if (footer != null)
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(footer),
              ),
          ],
        ),
      );

  List<PdfColor> _styleColors(PdfTravelBookStyle style) => switch (style) {
        PdfTravelBookStyle.classic => [
            PdfColors.blueGrey800,
            PdfColors.blueGrey500,
          ],
        PdfTravelBookStyle.editorial => [
            PdfColor.fromHex('#FF8A80'),
            PdfColor.fromHex('#B388FF'),
          ],
        PdfTravelBookStyle.scrapbook => [
            PdfColor.fromHex('#FFCC80'),
            PdfColor.fromHex('#F48FB1'),
          ],
      };

  String _safeFileName(JourneyExportData data) {
    final raw =
        (data.title.trim().isEmpty ? data.destination : data.title).trim();
    final cleaned = raw
        .replaceAll(RegExp(r'[^a-zA-Z0-9-_ ]'), '')
        .trim()
        .replaceAll(' ', '_');
    return (cleaned.isEmpty ? 'Journey' : cleaned) + '_Wonderlog.pdf';
  }
}
