import 'package:flutter/widgets.dart';

import 'app/wonderlog_app.dart';
import 'core/app_controller.dart';
import 'core/config/app_config.dart';
import 'core/database/wonderlog_database.dart';
import 'core/identity/supabase_identity_service.dart';
import 'core/profile/shared_preferences_profile_repository.dart';
import 'features/location/data/open_street_map_repository.dart';
import 'features/memories/data/drift_wonderlog_repository.dart';
import 'features/memories/data/photo_import_service.dart';
import 'features/premium/application/premium_entitlement_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = WonderlogDatabase();
  final repository = DriftWonderlogRepository(database);
  final locationRepository = OpenStreetMapRepository(database);
  final photoImportService = await createPlatformPhotoImportService();
  final controller = AppController(
    profileRepository: SharedPreferencesProfileRepository(),
    identityService: SupabaseIdentityService(AppConfig.current),
    premiumService: PremiumEntitlementService(),
  );
  await controller.initialize();

  runApp(
    WonderlogApp(
      controller: controller,
      repository: repository,
      locationRepository: locationRepository,
      photoImportService: photoImportService,
    ),
  );
}
