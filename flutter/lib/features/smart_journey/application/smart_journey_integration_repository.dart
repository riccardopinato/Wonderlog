import 'package:uuid/uuid.dart';

import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../premium/domain/premium_creation_guard.dart';
import '../domain/smart_journey_creation_policy.dart';
import '../domain/smart_journey_models.dart';
import '../domain/smart_journey_photo_importer.dart';
import '../domain/smart_journey_reconstruction_engine.dart';

final class SmartJourneyIntegrationRepository {
  SmartJourneyIntegrationRepository({
    required this.repository,
    required this.photoImporter,
    required this.isPremium,
    this.creationPolicy = const SmartJourneyCreationPolicy(),
  });

  final WonderlogRepository repository;
  final SmartJourneyPhotoImporter photoImporter;
  final bool Function() isPremium;
  final SmartJourneyCreationPolicy creationPolicy;
  final Uuid _uuid = const Uuid();

  SmartJourneyDraft? _currentDraft;

  SmartJourneyDraft? get currentDraft => _currentDraft;

  void updateDraft(SmartJourneyDraft draft) {
    _currentDraft = draft;
  }

  void clearDraft() {
    _currentDraft = null;
  }

  Future<SmartJourneyDraft> analysePhotos({
    required List<SmartJourneySourcePhoto> photos,
    required PlaceResolver resolvePlace,
    SmartJourneyBuildOptions options = const SmartJourneyBuildOptions(),
    Future<void> Function(SmartJourneyAnalysisProgress progress)? onProgress,
  }) async {
    if (photos.isEmpty) {
      throw ArgumentError('At least one photo is required.');
    }

    Future<void> emit(
      SmartJourneyAnalysisPhase phase, [
      int? processed,
    ]) async {
      final callback = onProgress;
      if (callback == null) return;
      await callback(
        SmartJourneyAnalysisProgress(
          processed: processed ?? photos.length,
          total: photos.length,
          phase: phase,
        ),
      );
    }

    await emit(SmartJourneyAnalysisPhase.readingMetadata, 0);
    await emit(SmartJourneyAnalysisPhase.groupingDays);
    await emit(SmartJourneyAnalysisPhase.clusteringLocations);
    await emit(SmartJourneyAnalysisPhase.resolvingPlaces);

    final draft = await SmartJourneyReconstructionEngine(
      options: options,
    ).reconstruct(
      photos,
      resolvePlace: resolvePlace,
    );

    await emit(SmartJourneyAnalysisPhase.buildingDraft);
    _currentDraft = draft;
    await emit(SmartJourneyAnalysisPhase.complete);
    return draft;
  }

  Future<SmartJourneyCreationAllowance> evaluateCreationAllowance(
    SmartJourneyDraft draft,
  ) async {
    final journeys = await repository.watchJourneys().first;
    return creationPolicy.evaluate(
      currentJourneyCount: journeys.length,
      selectedPhotoCount: draft.includedPhotos.length,
      isPremium: isPremium(),
    );
  }

  Future<SmartJourneyCreationResult> createJourneyFromDraft(
    SmartJourneyDraft draft,
  ) async {
    final included = draft.photos.where((photo) => photo.included).toList()
      ..sort((a, b) {
        final first = a.source.effectiveTimestamp;
        final second = b.source.effectiveTimestamp;
        if (first == null && second != null) return 1;
        if (first != null && second == null) return -1;
        if (first != null && second != null) {
          final time = first.compareTo(second);
          if (time != 0) return time;
        }
        return a.source.originalIndex.compareTo(b.source.originalIndex);
      });

    if (included.isEmpty) {
      throw ArgumentError('The Journey must contain at least one photo.');
    }

    final creationGuard = PremiumCreationGuard(
      repository: repository,
      isPremium: isPremium,
    );
    try {
      await creationGuard.ensureJourneyAllowed();
    } on PremiumCreationLimitException {
      throw const SmartJourneyLimitException(
        'Your current plan has reached the Journey limit.',
      );
    }

    final allowance = await evaluateCreationAllowance(draft);
    if (!allowance.journeyCreationAllowed) {
      throw const SmartJourneyLimitException(
        'Your current plan has reached the Journey limit.',
      );
    }
    if (allowance.allowedPhotoCount <= 0) {
      throw const SmartJourneyLimitException(
        'No additional photos can be added to this Journey.',
      );
    }

    final importable = included.take(allowance.allowedPhotoCount).toList();
    final importableIds = importable.map((photo) => photo.id).toSet();
    final plannedMemoryCount = draft.createMemoryDrafts
        ? draft.days
            .expand((day) => day.stops)
            .where(
              (stop) =>
                  stop.createMemory &&
                  stop.photoIds.any(importableIds.contains),
            )
            .length
        : 0;
    try {
      creationGuard.ensureNewJourneyMemoryBatchAllowed(
        requested: plannedMemoryCount,
      );
    } on PremiumCreationLimitException {
      throw const SmartJourneyLimitException(
        'Your current plan has reached the Memory limit for this Journey.',
      );
    }

    final startDate = draft.startDate ?? DateTime.now();
    final endDate = draft.endDate ?? startDate;
    final journey = await repository.createJourney(
      title: draft.title.trim().isEmpty
          ? draft.suggestedTitle
          : draft.title.trim(),
      destination: draft.destination.trim().isEmpty
          ? draft.title.trim()
          : draft.destination.trim(),
      startDate: startDate,
      endDate: endDate,
    );

    final realPhotoIdByDraftId = <String, String>{};
    final existingPhotos = <AlbumPhotoEntry>[];

    for (var index = 0; index < importable.length; index++) {
      final draftPhoto = importable[index];
      final realPhoto = await photoImporter.importPhoto(
        journeyId: journey.id,
        sourceUri: draftPhoto.source.sourceUri,
        displayOrder: index,
        existingPhotos: List.unmodifiable(existingPhotos),
      );
      await repository.savePhoto(realPhoto);
      existingPhotos.add(realPhoto);
      realPhotoIdByDraftId[draftPhoto.id] = realPhoto.id;
    }

    var memoryCount = 0;
    if (draft.createMemoryDrafts) {
      for (final day in draft.days) {
        for (final stop in day.stops.where((stop) => stop.createMemory)) {
        final realPhotoIds = stop.photoIds
            .map((draftId) => realPhotoIdByDraftId[draftId])
            .whereType<String>()
            .toList(growable: false);
        if (realPhotoIds.isEmpty) continue;

        final now = DateTime.now().toUtc();
        final memoryId = 'mem_' + _uuid.v4().replaceAll('-', '');
        await repository.saveMemory(
          MemoryEntry(
            id: memoryId,
            journeyId: journey.id,
            title: stop.title,
            journalText: '',
            locationName: stop.placeLabel ?? '',
            latitude: stop.latitude,
            longitude: stop.longitude,
            date: day.date,
            mood: Mood.calm,
            tags: const [],
            favorite: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repository.replaceMemoryPhotoLinks(
          memoryId: memoryId,
          photoIds: realPhotoIds,
        );
          memoryCount++;
        }
      }
    }

    clearDraft();
    return SmartJourneyCreationResult(
      journeyId: journey.id,
      photoCount: realPhotoIdByDraftId.length,
      memoryDraftCount: memoryCount,
    );
  }
}
