import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/features/memories/application/memory_life_bridge_adapter.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';

void main() {
  test('Memory exports as Anna travel_memory without leaking local media path',
      () {
    final memory = MemoryEntry(
      id: 'm1',
      journeyId: 'j1',
      title: 'Cascate',
      journalText: 'Una giornata alle cascate.',
      locationName: 'Cascate di Riva',
      date: DateTime.utc(2026, 8, 10),
      mood: Mood.calm,
      tags: const ['trekking'],
      latitude: 46.92,
      longitude: 11.95,
      createdAt: DateTime.utc(2026, 8, 10),
      updatedAt: DateTime.utc(2026, 8, 10, 18),
    );
    final photo = AlbumPhotoEntry(
      id: 'p1',
      journeyId: 'j1',
      localUri: '/private/photo.jpg',
      thumbnailUri: '/private/thumb.jpg',
      originalUri: '/private/photo.jpg',
      fileName: 'photo.jpg',
      mimeType: 'image/jpeg',
      width: 100,
      height: 100,
      fileSize: 123,
      createdAt: DateTime.utc(2026, 8, 10),
      updatedAt: DateTime.utc(2026, 8, 10),
    );

    final payload = MemoryLifeBridgeAdapter.payloadForAnna(
      memory,
      photos: [photo],
      transferMode: EcosystemTransferMode.copy,
    );
    final encoded = payload.encode();

    expect(payload.objectType, 'travel_memory');
    expect(payload.location?['name'], 'Cascate di Riva');
    expect(payload.bridgeId, 'ecosystem:v1:wonderlog:memory:m1');
    expect(encoded, isNot(contains('/private/photo.jpg')));
    expect(encoded, contains('"transfer": "omitted"'));
  });
}
