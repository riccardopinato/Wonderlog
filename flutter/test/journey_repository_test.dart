import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';

void main() {
  late WonderlogDatabase database;
  late DriftWonderlogRepository repository;

  setUp(() {
    database = WonderlogDatabase(NativeDatabase.memory());
    repository = DriftWonderlogRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('created journey is emitted by the local repository', () async {
    await repository.createJourney(
      title: 'Valle Aurina 2026',
      destination: 'Campo Tures',
      startDate: DateTime(2026, 8, 10),
      endDate: DateTime(2026, 8, 14),
    );

    final journeys = await repository.watchJourneys().first;

    expect(journeys, hasLength(1));
    expect(journeys.single.title, 'Valle Aurina 2026');
    expect(journeys.single.destination, 'Campo Tures');
  });

  test('invalid date range is rejected before persistence', () async {
    expect(
      () => repository.createJourney(
        title: 'Invalid',
        destination: 'Nowhere',
        startDate: DateTime(2026, 8, 14),
        endDate: DateTime(2026, 8, 10),
      ),
      throwsArgumentError,
    );
  });

  test('archive restore and deletion impact preserve lifecycle semantics',
      () async {
    final journey = await repository.createJourney(
      title: 'Dolomiti',
      destination: 'Cortina',
      startDate: DateTime(2026, 7, 1),
      endDate: DateTime(2026, 7, 2),
    );
    final now = DateTime.utc(2026, 7, 1);
    await repository.saveMemory(
      MemoryEntry(
        id: 'memory-1',
        journeyId: journey.id,
        title: 'Passo',
        journalText: '',
        locationName: '',
        date: now,
        mood: Mood.calm,
        tags: const [],
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.savePhoto(
      AlbumPhotoEntry(
        id: 'photo-1',
        journeyId: journey.id,
        localUri: 'media://photo-1',
        thumbnailUri: 'media://photo-1',
        originalUri: '/tmp/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        width: 0,
        height: 0,
        fileSize: 4,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await repository.saveAttachment(
      MemoryAttachment(
        id: 'attachment-1',
        memoryId: 'memory-1',
        localUri: 'media://document-1',
        mimeType: 'application/pdf',
        attachmentType: 'DOCUMENT',
        createdAt: now,
        syncStatus: 'LOCAL_ONLY',
      ),
    );

    final impact = await repository.getJourneyDeletionImpact(journey.id);
    expect(impact.memoryCount, 1);
    expect(impact.photoCount, 1);
    expect(impact.attachmentCount, 1);

    await repository.setJourneyArchived(journey.id, true);
    expect(await repository.watchJourneys().first, isEmpty);
    expect(await repository.watchArchivedJourneys().first, hasLength(1));

    await repository.setJourneyArchived(journey.id, false);
    expect(await repository.watchJourneys().first, hasLength(1));
    expect(await repository.watchArchivedJourneys().first, isEmpty);
  });

  test('Memory can move between Journey and unassigned surface', () async {
    final journey = await repository.createJourney(
      title: 'Torino',
      destination: 'Torino',
      startDate: DateTime(2026, 10, 16),
      endDate: DateTime(2026, 10, 18),
    );
    final now = DateTime.utc(2026, 10, 16);
    await repository.saveMemory(
      MemoryEntry(
        id: 'memory-move',
        journeyId: null,
        title: 'Mole',
        journalText: '',
        locationName: 'Torino',
        date: now,
        mood: Mood.happy,
        tags: const [],
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(await repository.watchUnassignedMemories().first, hasLength(1));

    await repository.moveMemoryToJourney('memory-move', journey.id);
    expect(await repository.watchUnassignedMemories().first, isEmpty);
    expect(await repository.watchMemories(journey.id).first, hasLength(1));

    await repository.moveMemoryToJourney('memory-move', null);
    expect(await repository.watchUnassignedMemories().first, hasLength(1));
  });

  test('cover and unlink operations update photo relationships', () async {
    final journey = await repository.createJourney(
      title: 'Trip',
      destination: 'Place',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 1),
    );
    final now = DateTime.utc(2026, 1, 1);
    final memory = MemoryEntry(
      id: 'memory-link',
      journeyId: journey.id,
      title: 'Memory',
      journalText: '',
      locationName: '',
      date: now,
      mood: Mood.calm,
      tags: const [],
      createdAt: now,
      updatedAt: now,
    );
    await repository.saveMemory(memory);

    for (final id in ['p1', 'p2']) {
      await repository.savePhoto(
        AlbumPhotoEntry(
          id: id,
          journeyId: journey.id,
          localUri: 'media://$id',
          thumbnailUri: 'media://$id',
          originalUri: '/tmp/$id.jpg',
          fileName: '$id.jpg',
          mimeType: 'image/jpeg',
          width: 0,
          height: 0,
          fileSize: 4,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    await repository.linkPhotoToMemory(
      memoryId: memory.id,
      photoId: 'p1',
      displayOrder: 0,
      isHero: true,
    );
    expect(
      (await repository.watchMemory(memory.id).first)!.photos,
      hasLength(1),
    );

    await repository.setJourneyCoverPhoto(
      journeyId: journey.id,
      photoId: 'p2',
    );
    final album = await repository.watchAlbum(journey.id).first;
    expect(album.singleWhere((p) => p.id == 'p2').isCoverPhoto, isTrue);
    expect(album.singleWhere((p) => p.id == 'p1').isCoverPhoto, isFalse);

    await repository.unlinkPhotoFromMemory(
      memoryId: memory.id,
      photoId: 'p1',
    );
    expect(
      (await repository.watchMemory(memory.id).first)!.photos,
      isEmpty,
    );
  });

}
