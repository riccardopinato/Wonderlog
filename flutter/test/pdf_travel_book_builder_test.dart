import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/export/application/pdf_travel_book_builder.dart';
import 'package:wonderlog/features/export/domain/pdf_export_models.dart';

void main() {
  test('PDF builder creates a real document without image dependencies',
      () async {
    final result = await const PdfTravelBookBuilder().build(
      data: const JourneyExportData(
        journeyId: 'j',
        title: 'Valle Aurina',
        destination: 'Campo Tures',
        country: 'Italy',
        startDate: '2026-08-10',
        endDate: '2026-08-14',
        description: 'Trip description',
        coverPhotoUri: null,
        photos: [],
        memories: [
          ExportMemory(
            title: 'Cascate',
            journalText: 'A memory from the waterfalls.',
            date: '2026-08-10',
            location: 'Cascate di Riva',
            mood: 'Calm',
            photoUris: [],
          ),
        ],
      ),
      options: const PdfExportOptions(),
    );

    expect(result.bytes.length, greaterThan(100));
    expect(
      ascii.decode(result.bytes.take(4).toList(), allowInvalid: true),
      '%PDF',
    );
    expect(result.fileName, 'Valle_Aurina_Wonderlog.pdf');
    expect(result.pageCount, 3);
  });
}
