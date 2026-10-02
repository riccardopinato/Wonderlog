import 'ecosystem_contract_validator.dart';
import 'ecosystem_envelope.dart';
import 'ecosystem_local_transport.dart';
import 'ecosystem_local_transport_port.dart';
import 'ecosystem_models.dart';
import 'ecosystem_transfer_planner.dart';
import 'ecosystem_transfer_store.dart';

enum EcosystemDeliveryStatus {
  openedTarget,
  fallbackCopied,
  unsupported,
}

final class EcosystemDeliveryResult {
  const EcosystemDeliveryResult({
    required this.status,
    required this.package,
    this.error,
  });

  final EcosystemDeliveryStatus status;
  final EcosystemTransferPackage package;
  final String? error;
}

final class EcosystemTransferService {
  const EcosystemTransferService({
    required this.store,
    required this.localTransport,
  });

  final EcosystemTransferStore store;
  final EcosystemLocalTransportPort localTransport;

  Future<EcosystemDeliveryResult> send({
    required EcosystemAppId targetApp,
    required EcosystemEnvelope envelope,
  }) async {
    EcosystemContractValidator.ensureValid(envelope);

    final package = EcosystemTransferPackage(
      targetApp: targetApp,
      envelope: envelope,
      createdAtUtc: DateTime.now().toUtc(),
    );

    if (!EcosystemTransferPlanner.canSend(envelope, targetApp)) {
      return EcosystemDeliveryResult(
        status: EcosystemDeliveryStatus.unsupported,
        package: package,
        error: 'target_capability_not_supported',
      );
    }

    final outboxId = await store.enqueueOutbox(
      targetApp: targetApp,
      envelope: envelope,
    );

    try {
      final uri = EcosystemLocalTransportCodec.targetUri(package);
      final opened = await localTransport.tryOpen(uri);
      if (opened) {
        await store.markOutboxDelivered(
          outboxId,
          deliveredAt: DateTime.now().toUtc(),
        );
        return EcosystemDeliveryResult(
          status: EcosystemDeliveryStatus.openedTarget,
          package: package,
        );
      }
    } catch (error) {
      await store.markOutboxFailure(
        outboxId,
        error: error.toString(),
      );
    }

    final portable =
        EcosystemLocalTransportCodec.clipboardText(package);
    await localTransport.copyPortableFallback(portable);
    await store.markOutboxFailure(
      outboxId,
      error: 'target_unavailable_portable_fallback_copied',
    );

    return EcosystemDeliveryResult(
      status: EcosystemDeliveryStatus.fallbackCopied,
      package: package,
    );
  }
}
