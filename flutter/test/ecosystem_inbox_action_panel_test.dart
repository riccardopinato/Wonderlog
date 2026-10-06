import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wonderlog/features/ecosystem/presentation/ecosystem_inbox_action_panel.dart';
import 'package:wonderlog/l10n/app_localizations.dart';

void main() {
  testWidgets('E2 action panel exposes all four official actions',
      (tester) async {
    var add = 0;
    var create = 0;
    var free = 0;
    var ignore = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EcosystemInboxActionPanel(
            onAddToJourney: () async => add++,
            onCreateJourney: () async => create++,
            onSaveFreeMemory: () async => free++,
            onIgnore: () async => ignore++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aggiungi a un viaggio esistente'));
    await tester.pump();
    await tester.tap(find.text('Crea nuovo viaggio'));
    await tester.pump();
    await tester.tap(find.text('Salva come ricordo libero'));
    await tester.pump();
    await tester.tap(find.text('Ignora e archivia'));
    await tester.pump();

    expect(add, 1);
    expect(create, 1);
    expect(free, 1);
    expect(ignore, 1);
  });

  testWidgets('E2 action panel disables all actions while one is running',
      (tester) async {
    final completer = Completer<void>();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EcosystemInboxActionPanel(
            onAddToJourney: () => completer.future,
            onCreateJourney: () async {},
            onSaveFreeMemory: () async {},
            onIgnore: () async {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aggiungi a un viaggio esistente'));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(
              FilledButton,
              'Aggiungi a un viaggio esistente',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Crea nuovo viaggio'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Salva come ricordo libero'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Ignora e archivia'),
          )
          .onPressed,
      isNull,
    );

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.byType(LinearProgressIndicator), findsNothing);
  });
}
