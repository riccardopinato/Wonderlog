import 'ecosystem_envelope.dart';
import 'ecosystem_models.dart';

final class EcosystemOutboxItem {
  const EcosystemOutboxItem({
    required this.id,
    required this.targetApp,
    required this.envelope,
    required this.createdAt,
    required this.attemptCount,
    this.deliveredAt,
    this.lastError,
  });

  final String id;
  final EcosystemAppId targetApp;
  final EcosystemEnvelope envelope;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final int attemptCount;
  final String? lastError;
}

enum EcosystemInboxDisposition {
  pending,
  processing,
  addedToJourney,
  createdJourney,
  savedFreeMemory,
  ignored,
  seenLegacy;

  static EcosystemInboxDisposition fromWire(
    String? value, {
    required bool consumed,
  }) {
    if (value == null || value.isEmpty) {
      return consumed
          ? EcosystemInboxDisposition.seenLegacy
          : EcosystemInboxDisposition.pending;
    }
    return EcosystemInboxDisposition.values.firstWhere(
      (item) => item.name == value,
      orElse: () => consumed
          ? EcosystemInboxDisposition.seenLegacy
          : EcosystemInboxDisposition.pending,
    );
  }
}

final class EcosystemInboxItem {
  const EcosystemInboxItem({
    required this.id,
    required this.sourceApp,
    required this.envelope,
    required this.receivedAt,
    this.consumedAt,
    this.disposition = EcosystemInboxDisposition.pending,
    this.materializedJourneyId,
    this.materializedMemoryId,
  });

  final String id;
  final EcosystemAppId sourceApp;
  final EcosystemEnvelope envelope;
  final DateTime receivedAt;
  final DateTime? consumedAt;
  final EcosystemInboxDisposition disposition;
  final String? materializedJourneyId;
  final String? materializedMemoryId;

  bool get isPending =>
      consumedAt == null && disposition == EcosystemInboxDisposition.pending;
}

abstract interface class EcosystemTransferStore {
  Stream<List<EcosystemOutboxItem>> watchPendingOutbox();

  Stream<List<EcosystemOutboxItem>> watchOutboxHistory();

  Future<String> enqueueOutbox({
    required EcosystemAppId targetApp,
    required EcosystemEnvelope envelope,
  });

  Future<void> markOutboxDelivered(
    String id, {
    required DateTime deliveredAt,
  });

  Future<void> markOutboxFailure(
    String id, {
    required String error,
  });

  Future<void> receiveInbox(EcosystemEnvelope envelope);

  Stream<List<EcosystemInboxItem>> watchPendingInbox();

  Stream<List<EcosystemInboxItem>> watchInboxHistory();

  Future<T?> runInboxMaterialization<T>(
    String id,
    Future<T> Function() materialize,
  );

  Future<void> resolveInbox(
    String id, {
    required EcosystemInboxDisposition disposition,
    required DateTime resolvedAt,
    String? materializedJourneyId,
    String? materializedMemoryId,
  });

  Future<void> markInboxConsumed(
    String id, {
    required DateTime consumedAt,
  });
}
