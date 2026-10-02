import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../features/location/domain/location_repository.dart';
import '../features/memories/data/photo_import_service.dart';
import '../features/memories/domain/wonderlog_repository.dart';
import '../features/onboarding/presentation/onboarding_gate.dart';
import '../features/shell/presentation/wonderlog_shell.dart';
import '../l10n/app_localizations.dart';
import 'theme/wonderlog_theme.dart';

final class WonderlogApp extends StatelessWidget {
  const WonderlogApp({
    super.key,
    required this.controller,
    required this.repository,
    required this.locationRepository,
    required this.photoImportService,
  });

  final AppController controller;
  final WonderlogRepository repository;
  final LocationRepository locationRepository;
  final PhotoImportService photoImportService;

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
        home: OnboardingGate(
          child: WonderlogShell(
            controller: controller,
            repository: repository,
            locationRepository: locationRepository,
            photoImportService: photoImportService,
          ),
        ),
      ),
    );
  }
}
