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

final class EcosystemInboxItem {
  const EcosystemInboxItem({
    required this.id,
    required this.sourceApp,
    required this.envelope,
    required this.receivedAt,
    this.consumedAt,
  });

  final String id;
  final EcosystemAppId sourceApp;
  final EcosystemEnvelope envelope;
  final DateTime receivedAt;
  final DateTime? consumedAt;
}

abstract interface class EcosystemTransferStore {
  Stream<List<EcosystemOutboxItem>> watchPendingOutbox();

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

  Future<void> markInboxConsumed(
    String id, {
    required DateTime consumedAt,
  });
}
