import 'package:flutter/material.dart';

import '../core/app_controller.dart';
import '../core/ecosystem/ecosystem_deep_link_listener.dart';
import '../core/ecosystem/ecosystem_inbound_transfer_service.dart';
import '../core/ecosystem/ecosystem_transfer_service.dart';
import '../core/ecosystem/ecosystem_transfer_store.dart';
import '../core/runtime/wonderlog_services_scope.dart';
import '../features/cloud/application/cloud_runtime_controller.dart';
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
    required this.ecosystemTransferStore,
    required this.ecosystemTransferService,
    required this.ecosystemInboundTransferService,
    required this.cloudRuntime,
  });

  final AppController controller;
  final WonderlogRepository repository;
  final LocationRepository locationRepository;
  final PhotoImportService photoImportService;
  final EcosystemTransferStore ecosystemTransferStore;
  final EcosystemTransferService ecosystemTransferService;
  final EcosystemInboundTransferService ecosystemInboundTransferService;
  final CloudRuntimeController? cloudRuntime;

  @override
  Widget build(BuildContext context) {
    final services = WonderlogServices(
      controller: controller,
      repository: repository,
      locationRepository: locationRepository,
      photoImportService: photoImportService,
      ecosystemTransferStore: ecosystemTransferStore,
      ecosystemTransferService: ecosystemTransferService,
      ecosystemInboundTransferService: ecosystemInboundTransferService,
      cloudRuntime: cloudRuntime,
    );

    return WonderlogServicesScope(
      services: services,
      child: EcosystemDeepLinkListener(
        inboundService: ecosystemInboundTransferService,
        child: AnimatedBuilder(
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
      ),
    ),
    );
  }
}
