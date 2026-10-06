import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/media/content_addressed_media_asset_store.dart';
import 'package:wonderlog/core/media/memory_media_asset_backend.dart';
import 'package:wonderlog/core/media/media_asset_reference.dart';
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

  test('Keepsake importer persists a private content-addressed copy', () async {
    final backend = MemoryMediaAssetBackend();
    final store = ContentAddressedMediaAssetStore(backend);
    final service = PhotoImportService(
      mediaStore: store,
      byteReader: _Reader(
        Uint8List.fromList([0x25, 0x50, 0x44, 0x46]),
      ),
    );

    final attachment = await service.importKeepsake(
      memoryId: 'memory',
      sourceUri: '/tmp/ticket.pdf',
      existingAttachments: const [],
      fileName: 'ticket.pdf',
      mimeType: 'application/pdf',
    );

    expect(attachment.localUri, startsWith('media://sha256_'));
    expect(attachment.attachmentType, 'DOCUMENT');
    final assetId = MediaAssetReference.tryDecode(attachment.localUri);
    expect(assetId, isNotNull);
    expect(await store.read(assetId!), isNotEmpty);
  });

  test('media cleanup preserves shared blobs until last reference is gone',
      () async {
    final backend = MemoryMediaAssetBackend();
    final store = ContentAddressedMediaAssetStore(backend);
    final service = PhotoImportService(
      mediaStore: store,
      byteReader: _Reader(Uint8List.fromList([1, 2, 3, 4])),
    );
    final assetId = await store.putOriginal([1, 2, 3, 4]);
    final reference = MediaAssetReference.encode(assetId);

    await service.deleteStoredReferenceIfUnreferenced(
      reference,
      remainingReferences: {reference},
    );
    expect(await store.read(assetId), isNotNull);

    await service.deleteStoredReferenceIfUnreferenced(
      reference,
      remainingReferences: const {},
    );
    expect(await store.read(assetId), isNull);
  });
}

final class _Reader implements SourceByteReader {
  const _Reader(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List> read(String reference) async => bytes;
}
