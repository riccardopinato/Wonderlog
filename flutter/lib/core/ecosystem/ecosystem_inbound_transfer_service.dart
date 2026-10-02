import 'ecosystem_contract_validator.dart';
import 'ecosystem_local_transport.dart';
import 'ecosystem_models.dart';
import 'ecosystem_transfer_planner.dart';
import 'ecosystem_transfer_store.dart';

enum EcosystemInboundStatus {
  accepted,
  wrongTarget,
  unsupported,
  invalid,
}

final class EcosystemInboundResult {
  const EcosystemInboundResult({
    required this.status,
    this.package,
    this.reason,
  });

  final EcosystemInboundStatus status;
  final EcosystemTransferPackage? package;
  final String? reason;
}

final class EcosystemInboundTransferService {
  const EcosystemInboundTransferService({
    required this.store,
    this.localApp = EcosystemAppId.wonderlog,
  });

  final EcosystemTransferStore store;
  final EcosystemAppId localApp;

  Future<EcosystemInboundResult> acceptUri(Uri uri) async {
    EcosystemTransferPackage package;
    try {
      package = EcosystemLocalTransportCodec.decodeTargetUri(uri);
    } catch (error) {
      return EcosystemInboundResult(
        status: EcosystemInboundStatus.invalid,
        reason: error.toString(),
      );
    }

    return acceptPackage(package);
  }

  Future<EcosystemInboundResult> acceptEncoded(
    String encodedPayload,
  ) async {
    EcosystemTransferPackage package;
    try {
      package = EcosystemLocalTransportCodec.decode(encodedPayload);
    } catch (error) {
      return EcosystemInboundResult(
        status: EcosystemInboundStatus.invalid,
        reason: error.toString(),
      );
    }

    return acceptPackage(package);
  }

  Future<EcosystemInboundResult> acceptClipboardText(
    String clipboardText,
  ) async {
    EcosystemTransferPackage package;
    try {
      package = EcosystemLocalTransportCodec.decodeClipboardText(
        clipboardText,
      );
    } catch (error) {
      return EcosystemInboundResult(
        status: EcosystemInboundStatus.invalid,
        reason: error.toString(),
      );
    }

    return acceptPackage(package);
  }

  Future<EcosystemInboundResult> acceptPackage(
    EcosystemTransferPackage package,
  ) async {
    if (package.targetApp != localApp) {
      return EcosystemInboundResult(
        status: EcosystemInboundStatus.wrongTarget,
        package: package,
        reason: 'wrong_target',
      );
    }

    final validation = EcosystemContractValidator.validate(
      package.envelope,
    );
    if (!validation.valid) {
      return EcosystemInboundResult(
        status: EcosystemInboundStatus.invalid,
        package: package,
        reason: validation.reason,
      );
    }

    if (!EcosystemTransferPlanner.canSend(
      package.envelope,
      localApp,
    )) {
      return EcosystemInboundResult(
        status: EcosystemInboundStatus.unsupported,
        package: package,
        reason: 'target_capability_not_supported',
      );
    }

    await store.receiveInbox(package.envelope);
    return EcosystemInboundResult(
      status: EcosystemInboundStatus.accepted,
      package: package,
    );
  }
}
