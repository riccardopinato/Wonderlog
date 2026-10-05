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
  ) async {
    _ensurePending(item);
    final journey = await repository.watchJourney(journeyId).first;
    if (journey == null) {
      throw StateError('Journey not found.');
    }
    await _ensureMemoryAllowance();
    final memory = _memoryFrom(item, journeyId: journeyId);
    await repository.saveMemory(memory);
    final resolvedAt = DateTime.now().toUtc();
    try {
      await store.resolveInbox(
        item.id,
        disposition: EcosystemInboxDisposition.addedToJourney,
        resolvedAt: resolvedAt,
        materializedJourneyId: journeyId,
        materializedMemoryId: memory.id,
      );
    } catch (_) {
      await repository.deleteMemory(memory.id);
      rethrow;
    }
    return EcosystemInboxMaterializationResult(
      disposition: EcosystemInboxDisposition.addedToJourney,
      journeyId: journeyId,
      memoryId: memory.id,
    );
  }

  Future<EcosystemInboxMaterializationResult> createJourney({
    required EcosystemInboxItem item,
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    _ensurePending(item);
    final premium = isPremium();
    final journeys = await repository.watchJourneys().first;
    final journeyCheck =
        premiumGate.canCreateJourney(journeys.length, premium);
    if (journeyCheck is PremiumLimitReached) {
      throw EcosystemInboxLimitException(journeyCheck);
    }
    await _ensureMemoryAllowance();

    final journey = await repository.createJourney(
      title: title,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      description: _description(item),
    );
    final memory = _memoryFrom(item, journeyId: journey.id);
    try {
      await repository.saveMemory(memory);
      await store.resolveInbox(
        item.id,
        disposition: EcosystemInboxDisposition.createdJourney,
        resolvedAt: DateTime.now().toUtc(),
        materializedJourneyId: journey.id,
        materializedMemoryId: memory.id,
      );
    } catch (_) {
      await repository.deleteJourney(journey.id);
      rethrow;
    }

    return EcosystemInboxMaterializationResult(
      disposition: EcosystemInboxDisposition.createdJourney,
      journeyId: journey.id,
      memoryId: memory.id,
    );
  }

  Future<EcosystemInboxMaterializationResult> saveFreeMemory(
    EcosystemInboxItem item,
  ) async {
    _ensurePending(item);
    await _ensureMemoryAllowance();
    final memory = _memoryFrom(item, journeyId: null);
    await repository.saveMemory(memory);
    try {
      await store.resolveInbox(
        item.id,
        disposition: EcosystemInboxDisposition.savedFreeMemory,
        resolvedAt: DateTime.now().toUtc(),
        materializedMemoryId: memory.id,
      );
    } catch (_) {
      await repository.deleteMemory(memory.id);
      rethrow;
    }
    return EcosystemInboxMaterializationResult(
      disposition: EcosystemInboxDisposition.savedFreeMemory,
      memoryId: memory.id,
    );
  }

  Future<EcosystemInboxMaterializationResult> ignore(
    EcosystemInboxItem item,
  ) async {
    _ensurePending(item);
    await store.resolveInbox(
      item.id,
      disposition: EcosystemInboxDisposition.ignored,
      resolvedAt: DateTime.now().toUtc(),
    );
    return const EcosystemInboxMaterializationResult(
      disposition: EcosystemInboxDisposition.ignored,
    );
  }

  Future<void> _ensureMemoryAllowance() async {
    final memories = await repository.watchAllMemories().first;
    final check =
        premiumGate.canCreateMemory(memories.length, isPremium());
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
      throw StateError('Ecosystem inbox item has already been resolved.');
    }
  }
}
