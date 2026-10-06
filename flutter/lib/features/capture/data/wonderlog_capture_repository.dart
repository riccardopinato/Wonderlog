import 'package:uuid/uuid.dart';

import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../premium/application/premium_access_policy.dart';
import '../../premium/domain/premium_gate.dart';
import '../domain/capture_media_port.dart';
import '../domain/capture_models.dart';
import '../domain/capture_repository.dart';
import '../domain/capture_validator.dart';

final class WonderlogCaptureRepository implements CaptureRepository {
  WonderlogCaptureRepository({
    required this.repository,
    required this.mediaPort,
    required bool Function() isPremium,
    PremiumAccessPolicy? premiumAccessPolicy,
  }) : premiumAccessPolicy = premiumAccessPolicy ??
            PremiumAccessPolicy(
              repository: repository,
              isPremium: isPremium,
            );

  final WonderlogRepository repository;
  final CaptureMediaPort mediaPort;
  final PremiumAccessPolicy premiumAccessPolicy;
  final Uuid _uuid = const Uuid();

  @override
  Future<List<CaptureJourneyOption>> getJourneys() async {
    final journeys = await repository.watchJourneys().first;
    return journeys
        .map(
          (journey) => CaptureJourneyOption(
            id: journey.id,
            title: journey.title.trim().isEmpty
                ? journey.destination
                : journey.title,
            subtitle:
                _dateOnly(journey.startDate) + ' • ' + journey.destination,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CaptureMemoryOption>> getMemories(String journeyId) async {
    final memories = await repository.watchMemories(journeyId).first;
    return memories
        .map(
          (memory) => CaptureMemoryOption(
            id: memory.id,
            title: memory.title,
            dateLabel: _dateOnly(memory.date),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<CaptureSaveResult> save(CaptureDraft draft) async {
    final validation = CaptureValidator.validate(draft);
    if (!validation.valid) {
      throw ArgumentError(validation.message ?? 'Invalid draft.');
    }

    final journeyId = draft.journeyId;
    if (journeyId == null) {
      throw ArgumentError('Journey is required.');
    }

    var targetMemoryId = draft.memoryId;

    if (draft.createNewMemory) {
      final memoryCheck = await premiumAccessPolicy.canCreateMemory(
        journeyId: journeyId,
      );
      if (memoryCheck is PremiumLimitReached) {
        throw StateError('Memory limit reached for free plan.');
      }

      final newMemoryId = 'mem_' + _uuid.v4().replaceAll('-', '');
      final location = draft.location ?? _firstLocation(draft.items);
      final combinedText = _combinedText(draft);
      final now = DateTime.now().toUtc();

      await repository.saveMemory(
        MemoryEntry(
          id: newMemoryId,
          journeyId: journeyId,
          title: _resolvedTitle(draft),
          journalText: combinedText,
          locationName: location?.label ?? '',
          latitude: location?.latitude,
          longitude: location?.longitude,
          date: DateTime.now(),
          mood: Mood.happy,
          tags: const ['capture'],
          favorite: false,
          createdAt: now,
          updatedAt: now,
        ),
      );
      targetMemoryId = newMemoryId;
    } else if (targetMemoryId != null) {
      final incomingText = _combinedText(draft);
      if (incomingText.trim().isNotEmpty) {
        final existing =
            await repository.watchMemories(journeyId).first;
        MemoryEntry? target;
        for (final memory in existing) {
          if (memory.id == targetMemoryId) {
            target = memory;
            break;
          }
        }
        if (target != null) {
          final appended = [
            target.journalText.trim(),
            incomingText.trim(),
          ].where((value) => value.isNotEmpty).join('\n\n');
          await repository.saveMemory(
            MemoryEntry(
              id: target.id,
              journeyId: target.journeyId,
              title: target.title,
              journalText: appended,
              locationName: target.locationName,
              date: target.date,
              mood: target.mood,
              tags: target.tags,
              latitude: target.latitude,
              longitude: target.longitude,
              favorite: target.favorite,
              createdAt: target.createdAt,
              updatedAt: DateTime.now().toUtc(),
              displayOrder: target.displayOrder,
              syncStatus: target.syncStatus,
              futureCloudId: target.futureCloudId,
            ),
          );
        }
      }
    }

    final imageItems = draft.items
        .where((item) => item.type == CaptureContentType.image)
        .toList(growable: false);
    var importedPhotoCount = 0;

    if (imageItems.isNotEmpty) {
      final currentPhotos = await repository.watchAlbum(journeyId).first;
      final allowance = premiumAccessPolicy.photoImportAllowance(
        currentCount: currentPhotos.length,
        selectedCount: imageItems.length,
      );
      if (allowance.allowedCount == 0) {
        throw StateError('Photo limit reached for current plan.');
      }

      for (final item in imageItems.take(allowance.allowedCount)) {
        final imported = await mediaPort.importPhoto(
          journeyId: journeyId,
          item: item,
          displayOrder: currentPhotos.length + importedPhotoCount,
          existingPhotos: currentPhotos,
        );
        if (imported == null) continue;
        await repository.savePhoto(imported);
        importedPhotoCount++;

        if (targetMemoryId != null) {
          await repository.linkPhotoToMemory(
            memoryId: targetMemoryId,
            photoId: imported.id,
            displayOrder: importedPhotoCount - 1,
            isHero: importedPhotoCount == 1,
          );
        }
      }
    }

    var attachmentCount = 0;
    final fileItems = draft.items
        .where((item) => item.type == CaptureContentType.file)
        .toList(growable: false);

    if (fileItems.isNotEmpty) {
      if (targetMemoryId == null) {
        throw StateError('Travel documents require a Memory destination.');
      }
      for (final item in fileItems) {
        final attachment = await mediaPort.importKeepsake(
          memoryId: targetMemoryId,
          item: item,
        );
        if (attachment == null) continue;
        await repository.saveAttachment(attachment);
        attachmentCount++;
      }
    }

    return CaptureSaveResult(
      journeyId: journeyId,
      memoryId: targetMemoryId,
      importedPhotoCount: importedPhotoCount,
      attachmentCount: attachmentCount,
    );
  }

  String _combinedText(CaptureDraft draft) {
    final values = <String>[];
    if (draft.memoryText.trim().isNotEmpty) {
      values.add(draft.memoryText.trim());
    }
    for (final item in draft.items) {
      if (item.type != CaptureContentType.text &&
          item.type != CaptureContentType.link) {
        continue;
      }
      final value = (item.text ?? item.uri ?? '').trim();
      if (value.isNotEmpty) values.add(value);
    }
    return values.join('\n\n');
  }

  String _resolvedTitle(CaptureDraft draft) {
    if (draft.memoryTitle.trim().isNotEmpty) {
      return draft.memoryTitle.trim();
    }
    for (final item in draft.items) {
      final title = item.title?.trim();
      if (title != null && title.isNotEmpty) return title;
    }
    if (draft.items.any((item) => item.type == CaptureContentType.link)) {
      return 'Saved Link';
    }
    if (draft.items.any((item) => item.type == CaptureContentType.text)) {
      return 'Quick Thought';
    }
    if (draft.items.any((item) => item.type == CaptureContentType.file)) {
      return 'Travel Document';
    }
    return 'New Memory';
  }

  CaptureLocation? _firstLocation(List<CaptureIncomingItem> items) {
    for (final item in items) {
      if (item.location != null) return item.location;
    }
    return null;
  }

  String _dateOnly(DateTime value) {
    final date = value.toLocal();
    return date.year.toString().padLeft(4, '0') +
        '-' +
        date.month.toString().padLeft(2, '0') +
        '-' +
        date.day.toString().padLeft(2, '0');
  }
}
