import 'package:uuid/uuid.dart';

import '../../../core/ecosystem/ecosystem_transfer_store.dart';
import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../premium/domain/premium_gate.dart';

final class EcosystemInboxLimitException implements Exception {
  const EcosystemInboxLimitException(this.result);

  final PremiumLimitReached result;

  @override
  String toString() => 'EcosystemInboxLimitException(${result.feature.name})';
}

final class EcosystemInboxMaterializationResult {
  const EcosystemInboxMaterializationResult({
    required this.disposition,
    this.journeyId,
    this.memoryId,
  });

  final EcosystemInboxDisposition disposition;
  final String? journeyId;
  final String? memoryId;
}

final class EcosystemInboxMaterializationService {
  EcosystemInboxMaterializationService({
    required this.repository,
    required this.store,
    required this.isPremium,
    this.premiumGate = const PremiumGate(),
  });

  final WonderlogRepository repository;
  final EcosystemTransferStore store;
  final bool Function() isPremium;
  final PremiumGate premiumGate;
  final Uuid _uuid = const Uuid();

  Future<EcosystemInboxMaterializationResult> addToJourney(
    EcosystemInboxItem item,
    String journeyId,
  ) {
    _ensurePending(item);
    return store.materializeInboxExactlyOnce(
      item.id,
      materialize: () async {
        final journey = await repository.watchJourney(journeyId).first;
        if (journey == null) {
          throw StateError('Journey not found.');
        }
        await _ensureMemoryAllowanceForJourney(journeyId);

        final memory = _memoryFrom(item, journeyId: journeyId);
        await repository.saveMemory(memory);
        final result = EcosystemInboxMaterializationResult(
          disposition: EcosystemInboxDisposition.addedToJourney,
          journeyId: journeyId,
          memoryId: memory.id,
        );
        return EcosystemInboxMaterializationCommit(
          value: result,
          disposition: result.disposition,
          materializedJourneyId: journeyId,
          materializedMemoryId: memory.id,
        );
      },
    );
  }

  Future<EcosystemInboxMaterializationResult> createJourney({
    required EcosystemInboxItem item,
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    _ensurePending(item);
    return store.materializeInboxExactlyOnce(
      item.id,
      materialize: () async {
        final premium = isPremium();
        final journeys = await repository.watchJourneys().first;
        final journeyCheck =
            premiumGate.canCreateJourney(journeys.length, premium);
        if (journeyCheck is PremiumLimitReached) {
          throw EcosystemInboxLimitException(journeyCheck);
        }

        final memoryCheck = premiumGate.canCreateMemory(0, premium);
        if (memoryCheck is PremiumLimitReached) {
          throw EcosystemInboxLimitException(memoryCheck);
        }

        final journey = await repository.createJourney(
          title: title,
          destination: destination,
          startDate: startDate,
          endDate: endDate,
          description: _description(item),
        );
        final memory = _memoryFrom(item, journeyId: journey.id);
        await repository.saveMemory(memory);

        final result = EcosystemInboxMaterializationResult(
          disposition: EcosystemInboxDisposition.createdJourney,
          journeyId: journey.id,
          memoryId: memory.id,
        );
        return EcosystemInboxMaterializationCommit(
          value: result,
          disposition: result.disposition,
          materializedJourneyId: journey.id,
          materializedMemoryId: memory.id,
        );
      },
    );
  }

  Future<EcosystemInboxMaterializationResult> saveFreeMemory(
    EcosystemInboxItem item,
  ) {
    _ensurePending(item);
    return store.materializeInboxExactlyOnce(
      item.id,
      materialize: () async {
        await _ensureUnassignedMemoryAllowance();
        final memory = _memoryFrom(item, journeyId: null);
        await repository.saveMemory(memory);

        final result = EcosystemInboxMaterializationResult(
          disposition: EcosystemInboxDisposition.savedFreeMemory,
          memoryId: memory.id,
        );
        return EcosystemInboxMaterializationCommit(
          value: result,
          disposition: result.disposition,
          materializedMemoryId: memory.id,
        );
      },
    );
  }

  Future<EcosystemInboxMaterializationResult> ignore(
    EcosystemInboxItem item,
  ) {
    _ensurePending(item);
    return store.materializeInboxExactlyOnce(
      item.id,
      materialize: () async {
        const result = EcosystemInboxMaterializationResult(
          disposition: EcosystemInboxDisposition.ignored,
        );
        return const EcosystemInboxMaterializationCommit(
          value: result,
          disposition: EcosystemInboxDisposition.ignored,
        );
      },
    );
  }

  Future<void> _ensureMemoryAllowanceForJourney(String journeyId) async {
    final memories = await repository.watchMemories(journeyId).first;
    final check =
        premiumGate.canCreateMemory(memories.length, isPremium());
    if (check is PremiumLimitReached) {
      throw EcosystemInboxLimitException(check);
    }
  }

  Future<void> _ensureUnassignedMemoryAllowance() async {
    final memories = await repository.watchAllMemories().first;
    final unassigned =
        memories.where((memory) => memory.journeyId == null).length;
    final check = premiumGate.canCreateMemory(unassigned, isPremium());
    if (check is PremiumLimitReached) {
      throw EcosystemInboxLimitException(check);
    }
  }

  MemoryEntry _memoryFrom(
    EcosystemInboxItem item, {
    required String? journeyId,
  }) {
    final envelope = item.envelope;
    final place = envelope.places.isEmpty ? null : envelope.places.first;
    final now = DateTime.now().toUtc();
    final title = _title(item);
    final text = envelope.text?.trim();
    final fallback = envelope.fallback.plainText.trim();
    final journalText =
        (text != null && text.isNotEmpty) ? text : fallback == title ? '' : fallback;

    return MemoryEntry(
      id: 'mem_${_uuid.v4().replaceAll('-', '')}',
      journeyId: journeyId,
      title: title,
      journalText: journalText,
      locationName: place?.name.trim() ?? '',
      latitude: place?.latitude,
      longitude: place?.longitude,
      date: envelope.createdAtUtc.toLocal(),
      mood: Mood.calm,
      tags: <String>{
        'ecosystem',
        envelope.sourceApp.wireValue,
        ...envelope.tags.map((tag) => tag.trim()).where((tag) => tag.isNotEmpty),
      }.toList(growable: false),
      favorite: false,
      createdAt: now,
      updatedAt: now,
      syncStatus: 'LOCAL_ONLY',
    );
  }

  String _title(EcosystemInboxItem item) {
    final envelope = item.envelope;
    final explicit = envelope.title?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    for (final line
        in envelope.fallback.plainText.split(RegExp(r'[\r\n]+'))) {
      final normalized = line.trim();
      if (normalized.isNotEmpty) return normalized;
    }
    return envelope.sourceEntityType.name;
  }

  String _description(EcosystemInboxItem item) {
    final envelope = item.envelope;
    final text = envelope.text?.trim();
    if (text != null && text.isNotEmpty) return text;
    return envelope.fallback.plainText.trim();
  }

  void _ensurePending(EcosystemInboxItem item) {
    if (!item.isPending) {
      throw EcosystemInboxAlreadyResolvedException(item.id);
    }
  }
}
