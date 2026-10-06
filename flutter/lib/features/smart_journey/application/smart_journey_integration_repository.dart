import 'package:uuid/uuid.dart';

import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../premium/application/premium_access_policy.dart';
import '../../premium/domain/premium_gate.dart';
import '../domain/smart_journey_models.dart';
import '../domain/smart_journey_photo_importer.dart';
import '../domain/smart_journey_reconstruction_engine.dart';

final class SmartJourneyIntegrationRepository {
  SmartJourneyIntegrationRepository({
    required this.repository,
    required this.photoImporter,
    required bool Function() isPremium,
    PremiumAccessPolicy? premiumAccessPolicy,
  }) : premiumAccessPolicy = premiumAccessPolicy ??
            PremiumAccessPolicy(
              repository: repository,
              isPremium: isPremium,
            );

  final WonderlogRepository repository;
  final SmartJourneyPhotoImporter photoImporter;
  final PremiumAccessPolicy premiumAccessPolicy;
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
    final journeyGate = await premiumAccessPolicy.canCreateJourney();
    final photos = premiumAccessPolicy.photoImportAllowance(
      currentCount: 0,
      selectedCount: draft.includedPhotos.length,
    );
    final memories = premiumAccessPolicy.memoryCreationAllowanceForCount(
      currentCount: 0,
      selectedCount: _requestedMemoryCount(draft),
    );

    return SmartJourneyCreationAllowance(
      isPremium: premiumAccessPolicy.hasPremiumAccess,
      journeyCreationAllowed: journeyGate is PremiumAllowed,
      selectedPhotoCount: draft.includedPhotos.length,
      allowedPhotoCount: photos.allowedCount,
      blockedPhotoCount: photos.blockedCount,
      selectedMemoryCount: memories.selectedCount,
      allowedMemoryCount: memories.allowedCount,
      blockedMemoryCount: memories.blockedCount,
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
    if (allowance.hasBlockedMemories) {
      throw SmartJourneyLimitException(
        'Your current plan supports up to '
        '${allowance.allowedMemoryCount} Memories per Journey.',
      );
    }

    final importable = included.take(allowance.allowedPhotoCount).toList();
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
    for (final day in draft.days) {
      for (final stop in day.stops.where(
        (stop) => draft.createMemoryDrafts && stop.createMemory,
      )) {
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

    clearDraft();
    return SmartJourneyCreationResult(
      journeyId: journey.id,
      photoCount: realPhotoIdByDraftId.length,
      memoryDraftCount: memoryCount,
    );
  }
}
