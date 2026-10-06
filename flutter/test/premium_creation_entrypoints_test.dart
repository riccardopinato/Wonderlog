import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/journeys/presentation/journey_widgets.dart';
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';
import 'package:wonderlog/features/memories/presentation/memory_editor_page.dart';
import 'package:wonderlog/l10n/app_localizations.dart';

void main() {
  late WonderlogDatabase database;
  late DriftWonderlogRepository repository;

  setUp(() {
    database = WonderlogDatabase(NativeDatabase.memory());
    repository = DriftWonderlogRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('standard Journey dialog cannot bypass the free Journey limit',
      (tester) async {
    for (var index = 0; index < 3; index++) {
      await repository.createJourney(
        title: 'Journey $index',
        destination: 'Destination $index',
        startDate: DateTime(2026, 1, index + 1),
        endDate: DateTime(2026, 1, index + 1),
      );
    }

    await tester.pumpWidget(
      _localizedApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showCreateJourneyDialog(
                  context,
                  repository,
                  isPremium: () => false,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'Blocked Journey');
    await tester.enterText(fields.at(1), 'Blocked Destination');
    await tester.tap(find.widgetWithText(FilledButton, 'Salva'));
    await tester.pumpAndSettle();

    expect(await repository.countJourneys(), 3);
    expect(
      find.text('Hai raggiunto il limite di viaggi del piano attuale.'),
      findsOneWidget,
    );
  });

  testWidgets('standard Memory editor cannot bypass per-Journey free limit',
      (tester) async {
    final journey = await repository.createJourney(
      title: 'Valle Aurina',
      destination: 'Campo Tures',
      startDate: DateTime(2026, 8, 10),
      endDate: DateTime(2026, 8, 14),
    );
    for (var index = 0; index < 5; index++) {
      await repository.saveMemory(_memory('memory-$index', journey.id));
    }

    await tester.pumpWidget(
      _localizedApp(
        MemoryEditorPage(
          repository: repository,
          journeyId: journey.id,
          isPremium: () => false,
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Blocked Memory');
    await tester.tap(find.widgetWithText(FilledButton, 'Salva'));
    await tester.pumpAndSettle();

    expect(await repository.countMemoriesForJourney(journey.id), 5);
    expect(
      find.text('Hai raggiunto il limite di ricordi per questa destinazione.'),
      findsOneWidget,
    );
  });
}

Widget _localizedApp(Widget home) => MaterialApp(
      locale: const Locale('it'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

MemoryEntry _memory(String id, String journeyId) {
  final now = DateTime.utc(2026, 8, 10);
  return MemoryEntry(
    id: id,
    journeyId: journeyId,
    title: id,
    journalText: '',
    locationName: '',
    date: now,
    mood: Mood.calm,
    tags: const [],
    createdAt: now,
    updatedAt: now,
  );
}
