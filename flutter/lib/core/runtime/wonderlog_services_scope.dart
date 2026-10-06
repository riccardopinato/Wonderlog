import 'package:flutter/widgets.dart';

import '../../features/cloud/application/cloud_runtime_controller.dart';
import '../../features/location/domain/location_repository.dart';
import '../../features/location/domain/offline_map_service.dart';
import '../../features/map_memories/domain/road_routing_service.dart';
import '../../features/memories/data/photo_import_service.dart';
import '../../features/memories/domain/wonderlog_repository.dart';
import '../../features/premium/application/premium_access_policy.dart';
import '../app_controller.dart';
import '../ecosystem/ecosystem_inbound_transfer_service.dart';
import '../ecosystem/ecosystem_transfer_service.dart';
import '../ecosystem/ecosystem_transfer_store.dart';

final class WonderlogServices {
  WonderlogServices({
    required this.controller,
    required this.repository,
    required this.locationRepository,
    required this.offlineMapService,
    required this.roadRoutingService,
    required this.photoImportService,
    required this.ecosystemTransferStore,
    required this.ecosystemTransferService,
    required this.ecosystemInboundTransferService,
    this.cloudRuntime,
  }) : premiumAccessPolicy = PremiumAccessPolicy(
          repository: repository,
          isPremium: () => controller.isPremium,
        );

  final AppController controller;
  final WonderlogRepository repository;
  final LocationRepository locationRepository;
  final OfflineMapService offlineMapService;
  final RoadRoutingService roadRoutingService;
  final PhotoImportService photoImportService;
  final EcosystemTransferStore ecosystemTransferStore;
  final EcosystemTransferService ecosystemTransferService;
  final EcosystemInboundTransferService ecosystemInboundTransferService;
  final CloudRuntimeController? cloudRuntime;
  final PremiumAccessPolicy premiumAccessPolicy;
}

final class WonderlogServicesScope extends InheritedWidget {
  const WonderlogServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final WonderlogServices services;

  static WonderlogServices? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WonderlogServicesScope>()
          ?.services;

  static WonderlogServices of(BuildContext context) {
    final services = maybeOf(context);
    if (services == null) {
      throw StateError('WonderlogServicesScope not found.');
    }
    return services;
  }

  @override
  bool updateShouldNotify(WonderlogServicesScope oldWidget) =>
      !identical(services, oldWidget.services);
}
