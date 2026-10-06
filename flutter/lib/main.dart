import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'app/wonderlog_app.dart';
import 'core/app_controller.dart';
import 'core/config/app_config.dart';
import 'core/database/wonderlog_database.dart';
import 'core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'core/ecosystem/ecosystem_inbound_transfer_service.dart';
import 'core/ecosystem/ecosystem_transfer_service.dart';
import 'core/ecosystem/flutter_local_ecosystem_transport_port.dart';
import 'core/identity/supabase_identity_service.dart';
import 'core/profile/shared_preferences_profile_repository.dart';
import 'features/cloud/application/cloud_runtime_controller.dart';
import 'features/cloud/data/cloud_restore_repository.dart';
import 'features/cloud/data/drift_cloud_local_data_source.dart';
import 'features/cloud/data/drift_cloud_relationship_source.dart';
import 'features/cloud/data/drift_sync_queue_store.dart';
import 'features/cloud/data/media_asset_restored_photo_storage.dart';
import 'features/cloud/data/shared_preferences_cloud_backup_settings_repository.dart';
import 'features/cloud/data/supabase_cloud_provider.dart';
import 'features/cloud/domain/cloud_sync_repository.dart';
import 'features/location/data/open_street_map_repository.dart';
import 'features/memories/data/cloud_aware_wonderlog_repository.dart';
import 'features/memories/data/drift_wonderlog_repository.dart';
import 'features/memories/data/photo_import_service.dart';
import 'features/memories/domain/wonderlog_repository.dart';
import 'features/premium/application/premium_entitlement_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = WonderlogDatabase();
  final baseRepository = DriftWonderlogRepository(database);
  WonderlogRepository repository = baseRepository;

  final locationRepository = OpenStreetMapRepository(database);
  final ecosystemTransferStore = DriftEcosystemTransferStore(database);
  final ecosystemTransferService = EcosystemTransferService(
    store: ecosystemTransferStore,
    localTransport: const FlutterLocalEcosystemTransportPort(),
  );
  final ecosystemInboundTransferService = EcosystemInboundTransferService(
    store: ecosystemTransferStore,
  );
  final photoImportService = await createPlatformPhotoImportService();

  final controller = AppController(
    profileRepository: SharedPreferencesProfileRepository(),
    identityService: SupabaseIdentityService(AppConfig.current),
    premiumService: PremiumEntitlementService(),
  );
  await controller.initialize();

  CloudRuntimeController? cloudRuntime;
  if (AppConfig.current.cloudConfigured &&
      controller.identity.status != IdentityStatus.error) {
    final cloudProvider = SupabaseCloudProvider();
    final queueStore = DriftSyncQueueStore(database);
    final cloudLocalDataSource = DriftCloudLocalDataSource(
      database: database,
      currentUserId: () => controller.identity.user?.id,
    );
    final relationshipSource = DriftCloudRelationshipSource(
      database: database,
      currentUserId: () => controller.identity.user?.id,
    );
    final cloudSyncRepository = CloudSyncRepository(
      cloudProvider: cloudProvider,
      queueStore: queueStore,
      localDataSource: cloudLocalDataSource,
      assetReader: (reference) async {
        final bytes = await photoImportService.readReference(reference);
        return bytes == null ? null : Uint8List.fromList(bytes);
      },
      relationshipReader: relationshipSource.readAll,
    );
    final cloudRestoreRepository = CloudRestoreRepository(
      database: database,
      cloudProvider: cloudProvider,
      photoStorage: MediaAssetRestoredPhotoStorage(
        photoImportService.mediaStore,
      ),
    );
    final cloudSettings =
        SharedPreferencesCloudBackupSettingsRepository();

    cloudRuntime = CloudRuntimeController(
      cloudProvider: cloudProvider,
      syncRepository: cloudSyncRepository,
      restoreRepository: cloudRestoreRepository,
      settingsRepository: cloudSettings,
      queueStore: queueStore,
      isPremium: () => controller.isPremium,
      currentUserId: () => controller.identity.user?.id,
    );
    await cloudRuntime.initialize();

    repository = CloudAwareWonderlogRepository(
      delegate: baseRepository,
      cloudSyncRepository: cloudSyncRepository,
    );
  }

  runApp(
    WonderlogApp(
      controller: controller,
      repository: repository,
      locationRepository: locationRepository,
      photoImportService: photoImportService,
      ecosystemTransferStore: ecosystemTransferStore,
      ecosystemTransferService: ecosystemTransferService,
      ecosystemInboundTransferService: ecosystemInboundTransferService,
      cloudRuntime: cloudRuntime,
    ),
  );
}
