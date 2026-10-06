import 'package:uuid/uuid.dart';

import '../../../core/ecosystem/ecosystem_transfer_store.dart';
import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../../premium/domain/premium_creation_guard.dart';
import '../../premium/domain/premium_gate.dart';

final class EcosystemInboxLimitException implements Exception {
  const EcosystemInboxLimitException(this.result);

  final PremiumLimitReached result;

  @override
  String toString() => 'EcosystemInboxLimitException(${result.feature.name})';
}

final class EcosystemInboxAlreadyResolvedException implements Exception {
  const EcosystemInboxAlreadyResolvedException();

  @override
  String toString() => 'Ecosystem inbox item is no longer pending.';
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

  PremiumCreationGuard get _creationGuard => PremiumCreationGuard(
        repository: repository,
        isPremium: isPremium,
        gate: premiumGate,
      );

  Future<EcosystemInboxMaterializationResult> addToJourney(
    EcosystemInboxItem item,
    String journeyId,
  ) =>
      _runAtomically(
        item,
        () async {
          final journey = await repository.getJourney(journeyId);
          if (journey == null) {
            throw StateError('Journey not found.');
          }

          await _ensureMemoryAllowed(journeyId: journeyId);
          final memory = _memoryFrom(item, journeyId: journeyId);
          await repository.saveMemory(memory);
          await store.resolveInbox(
            item.id,
            disposition: EcosystemInboxDisposition.addedToJourney,
            resolvedAt: DateTime.now().toUtc(),
            materializedJourneyId: journeyId,
            materializedMemoryId: memory.id,
          );

          return EcosystemInboxMaterializationResult(
            disposition: EcosystemInboxDisposition.addedToJourney,
            journeyId: journeyId,
            memoryId: memory.id,
          );
        },
      );

  Future<EcosystemInboxMaterializationResult> createJourney({
    required EcosystemInboxItem item,
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
  }) =>
      _runAtomically(
        item,
        () async {
          await _ensureJourneyAllowed();
          await _ensureNewJourneyMemoryAllowed();

          final journey = await repository.createJourney(
            title: title,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            description: _description(item),
          );
          final memory = _memoryFrom(item, journeyId: journey.id);
          await repository.saveMemory(memory);
          await store.resolveInbox(
            item.id,
            disposition: EcosystemInboxDisposition.createdJourney,
            resolvedAt: DateTime.now().toUtc(),
            materializedJourneyId: journey.id,
            materializedMemoryId: memory.id,
          );

          return EcosystemInboxMaterializationResult(
            disposition: EcosystemInboxDisposition.createdJourney,
            journeyId: journey.id,
            memoryId: memory.id,
          );
        },
      );

  Future<EcosystemInboxMaterializationResult> saveFreeMemory(
    EcosystemInboxItem item,
  ) =>
      _runAtomically(
        item,
        () async {
          await _ensureMemoryAllowed(journeyId: null);
          final memory = _memoryFrom(item, journeyId: null);
          await repository.saveMemory(memory);
          await store.resolveInbox(
            item.id,
            disposition: EcosystemInboxDisposition.savedFreeMemory,
            resolvedAt: DateTime.now().toUtc(),
            materializedMemoryId: memory.id,
          );

          return EcosystemInboxMaterializationResult(
            disposition: EcosystemInboxDisposition.savedFreeMemory,
            memoryId: memory.id,
          );
        },
      );

  Future<EcosystemInboxMaterializationResult> ignore(
    EcosystemInboxItem item,
  ) =>
      _runAtomically(
        item,
        () async {
          await store.resolveInbox(
            item.id,
            disposition: EcosystemInboxDisposition.ignored,
            resolvedAt: DateTime.now().toUtc(),
          );
          return const EcosystemInboxMaterializationResult(
            disposition: EcosystemInboxDisposition.ignored,
          );
        },
      );

  Future<EcosystemInboxMaterializationResult> _runAtomically(
    EcosystemInboxItem item,
    Future<EcosystemInboxMaterializationResult> Function() materialize,
  ) async {
    _ensurePending(item);
    final result = await store.runInboxMaterialization(
      item.id,
      materialize,
    );
    if (result == null) {
      throw const EcosystemInboxAlreadyResolvedException();
    }
    return result;
  }

  Future<void> _ensureJourneyAllowed() async {
    try {
      await _creationGuard.ensureJourneyAllowed();
    } on PremiumCreationLimitException catch (error) {
      throw EcosystemInboxLimitException(error.result);
    }
  }

  Future<void> _ensureMemoryAllowed({
    required String? journeyId,
  }) async {
    try {
      await _creationGuard.ensureMemoryAllowed(journeyId: journeyId);
    } on PremiumCreationLimitException catch (error) {
      throw EcosystemInboxLimitException(error.result);
    }
  }

  Future<void> _ensureNewJourneyMemoryAllowed() async {
    try {
      _creationGuard.ensureNewJourneyMemoryBatchAllowed(requested: 1);
    } on PremiumCreationLimitException catch (error) {
      throw EcosystemInboxLimitException(error.result);
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
      throw const EcosystemInboxAlreadyResolvedException();
    }
  }
}
