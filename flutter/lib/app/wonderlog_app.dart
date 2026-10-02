import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../features/memories/domain/wonderlog_repository.dart';
import '../features/shell/presentation/wonderlog_shell.dart';
import '../l10n/app_localizations.dart';
import 'theme/wonderlog_theme.dart';

final class WonderlogApp extends StatelessWidget {
  const WonderlogApp({
    super.key,
    required this.controller,
    required this.repository,
  });

  final AppController controller;
  final WonderlogRepository repository;

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
          repository: repository,
        ),
      ),
    );
  }
}
