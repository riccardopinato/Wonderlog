import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../features/journeys/domain/journey_repository.dart';
import '../features/shell/presentation/wonderlog_shell.dart';
import '../l10n/app_localizations.dart';
import 'theme/wonderlog_theme.dart';

final class WonderlogApp extends StatelessWidget {
  const WonderlogApp({
    super.key,
    required this.controller,
    required this.journeyRepository,
  });

  final AppController controller;
  final JourneyRepository journeyRepository;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        theme: WonderlogTheme.light,
        darkTheme: WonderlogTheme.dark,
        themeMode: controller.themeMode,
        locale: controller.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: WonderlogShell(
          controller: controller,
          journeyRepository: journeyRepository,
        ),
      ),
    );
  }
}
