import 'package:flutter/widgets.dart';

import '../../features/location/domain/location_repository.dart';
import '../../features/memories/data/photo_import_service.dart';
import '../../features/memories/domain/wonderlog_repository.dart';
import '../app_controller.dart';
import '../ecosystem/ecosystem_inbound_transfer_service.dart';
import '../ecosystem/ecosystem_transfer_service.dart';
import '../ecosystem/ecosystem_transfer_store.dart';

final class WonderlogServices {
  const WonderlogServices({
    required this.controller,
    required this.repository,
    required this.locationRepository,
    required this.photoImportService,
    required this.ecosystemTransferStore,
    required this.ecosystemTransferService,
    required this.ecosystemInboundTransferService,
  });

  final AppController controller;
  final WonderlogRepository repository;
  final LocationRepository locationRepository;
  final PhotoImportService photoImportService;
  final EcosystemTransferStore ecosystemTransferStore;
  final EcosystemTransferService ecosystemTransferService;
  final EcosystemInboundTransferService ecosystemInboundTransferService;
}

final class WonderlogServicesScope extends InheritedWidget {
  const WonderlogServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final WonderlogServices services;

  static WonderlogServices of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<WonderlogServicesScope>();
    if (scope == null) {
      throw StateError('WonderlogServicesScope not found.');
    }
    return scope.services;
  }

  @override
  bool updateShouldNotify(WonderlogServicesScope oldWidget) =>
      !identical(services, oldWidget.services);
}
