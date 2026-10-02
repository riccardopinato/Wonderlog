import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_local_transport.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_local_transport_port.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_transfer_service.dart';

void main() {
  EcosystemEnvelope envelope() => EcosystemEnvelope(
        sourceApp: EcosystemAppId.wonderlog,
        sourceEntityType: EcosystemEntityType.journey,
        sourceEntityId: 'j1',
        createdAtUtc: DateTime.utc(2026),
        title: 'Trip',
        sourceDeepLink: 'wonderlog://journey/j1',
      );

  test('successful deep link marks outbox delivery complete', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final port = _FakePort(opened: true);
    final service = EcosystemTransferService(
      localApp: EcosystemAppId.wonderlog,
      store: store,
      localTransport: port,
    );

    final result = await service.send(
      targetApp: EcosystemAppId.annasDiary,
      envelope: envelope(),
    );

    expect(result.status, EcosystemDeliveryStatus.openedTarget);
    expect(await store.watchPendingOutbox().first, isEmpty);
    expect(port.lastUri?.scheme, 'annasdiary');
    await database.close();
  });

  test('missing target copies portable package and retains retryable outbox',
      () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final port = _FakePort(opened: false);
    final service = EcosystemTransferService(
      localApp: EcosystemAppId.wonderlog,
      store: store,
      localTransport: port,
    );

    final result = await service.send(
      targetApp: EcosystemAppId.annasDiary,
      envelope: envelope(),
    );

    expect(result.status, EcosystemDeliveryStatus.fallbackCopied);
    expect(port.clipboard, startsWith(ecosystemClipboardPrefix));
    expect(
      EcosystemLocalTransportCodec.decodeClipboardText(port.clipboard!)
          .envelope
          .bridgeId,
      'ecosystem:v1:wonderlog:journey:j1',
    );

    final pending = await store.watchPendingOutbox().first;
    expect(pending, hasLength(1));
    expect(pending.single.attemptCount, 1);
    await database.close();
  });
  test('local transport cannot impersonate another source app', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final service = EcosystemTransferService(
      localApp: EcosystemAppId.wonderlog,
      store: store,
      localTransport: _FakePort(opened: true),
    );
    final foreign = EcosystemEnvelope(
      sourceApp: EcosystemAppId.annasDiary,
      sourceEntityType: EcosystemEntityType.note,
      sourceEntityId: 'n1',
      createdAtUtc: DateTime.utc(2026),
      title: 'Anna note',
    );

    expect(
      () => service.send(
        targetApp: EcosystemAppId.notes,
        envelope: foreign,
      ),
      throwsStateError,
    );
    expect(await store.watchPendingOutbox().first, isEmpty);
    await database.close();
  });

  test('self-targeting transfer fails before persistence', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final service = EcosystemTransferService(
      localApp: EcosystemAppId.wonderlog,
      store: store,
      localTransport: _FakePort(opened: true),
    );

    expect(
      () => service.send(
        targetApp: EcosystemAppId.wonderlog,
        envelope: envelope(),
      ),
      throwsStateError,
    );
    expect(await store.watchPendingOutbox().first, isEmpty);
    await database.close();
  });
}

final class _FakePort implements EcosystemLocalTransportPort {
  _FakePort({required this.opened});

  final bool opened;
  Uri? lastUri;
  String? clipboard;

  @override
  Future<bool> tryOpen(Uri targetUri) async {
    lastUri = targetUri;
    return opened;
  }

  @override
  Future<void> copyPortableFallback(String portablePayload) async {
    clipboard = portablePayload;
  }
}
