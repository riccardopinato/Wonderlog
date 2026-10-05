import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_transfer_store.dart';
import 'package:wonderlog/features/home/presentation/ecosystem_inbox_home_card.dart';
import 'package:wonderlog/l10n/app_localizations.dart';

void main() {
  testWidgets('shows a persisted Anna ecosystem receipt on Home', (tester) async {
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.annasDiary,
      sourceEntityType: EcosystemEntityType.note,
      sourceEntityId: 'moment-42',
      createdAtUtc: DateTime.utc(2026, 10, 5, 13),
      title: 'Test E1 Anna → Wonderlog',
      text: 'Round trip fisico',
      sourceDeepLink: 'annasdiary://moment/moment-42',
      transferMode: EcosystemTransferMode.copy,
      revision: 1,
    );
    final store = _FakeEcosystemTransferStore(
      pending: [
        EcosystemInboxItem(
          id: 'inbox-1',
          sourceApp: EcosystemAppId.annasDiary,
          envelope: envelope,
          receivedAt: DateTime.utc(2026, 10, 5, 13),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EcosystemInboxHomeCard(store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ricevuti dalle app'), findsOneWidget);
    expect(find.text("Ricevuto da Anna's Diary"), findsOneWidget);
    expect(find.text('Test E1 Anna → Wonderlog'), findsOneWidget);
    expect(find.text('Round trip fisico'), findsOneWidget);
    expect(find.text('COPY'), findsOneWidget);
    expect(find.text('note'), findsOneWidget);
    expect(find.text('Segna come visto'), findsOneWidget);

    await tester.tap(find.text('Segna come visto'));
    await tester.pump();

    expect(store.consumedId, 'inbox-1');
  });
}

final class _FakeEcosystemTransferStore implements EcosystemTransferStore {
  _FakeEcosystemTransferStore({required this.pending});

  final List<EcosystemInboxItem> pending;
  String? consumedId;

  @override
  Stream<List<EcosystemInboxItem>> watchPendingInbox() =>
      Stream<List<EcosystemInboxItem>>.value(pending);

  @override
  Future<void> markInboxConsumed(
    String id, {
    required DateTime consumedAt,
  }) async {
    consumedId = id;
  }

  @override
  Stream<List<EcosystemOutboxItem>> watchPendingOutbox() =>
      const Stream<List<EcosystemOutboxItem>>.empty();

  @override
  Future<String> enqueueOutbox({
    required EcosystemAppId targetApp,
    required EcosystemEnvelope envelope,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> markOutboxDelivered(
    String id, {
    required DateTime deliveredAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> markOutboxFailure(
    String id, {
    required String error,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> receiveInbox(EcosystemEnvelope envelope) =>
      throw UnimplementedError();
}
