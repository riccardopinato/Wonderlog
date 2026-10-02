import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/media/content_addressed_media_asset_store.dart';
import 'package:wonderlog/core/media/memory_media_asset_backend.dart';
import 'package:wonderlog/core/media/source_byte_reader_io.dart';
import 'package:wonderlog/features/memories/data/photo_import_service.dart';

void main() {
  test('photo importer stores supported image bytes by content hash', () async {
    final store = ContentAddressedMediaAssetStore(
      MemoryMediaAssetBackend(),
    );
    final service = PhotoImportService(
      mediaStore: store,
      byteReader: _Reader(
        Uint8List.fromList([0xff, 0xd8, 0xff, 0xd9]),
      ),
    );

    final photo = await service.importPhoto(
      journeyId: 'j',
      sourceUri: '/tmp/photo.jpg',
      displayOrder: 0,
      existingPhotos: const [],
    );

    expect(photo.mimeType, 'image/jpeg');
    expect(photo.localUri, startsWith('media://sha256_'));
    expect(photo.fileSize, 4);
  });
}

final class _Reader implements SourceByteReader {
  const _Reader(this.bytes);
  final Uint8List bytes;

  @override
  Future<Uint8List> read(String reference) async => bytes;
}
