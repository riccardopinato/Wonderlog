import 'package:flutter/widgets.dart';

import 'app/wonderlog_app.dart';
import 'core/app_controller.dart';
import 'core/config/app_config.dart';
import 'core/database/wonderlog_database.dart';
import 'core/identity/supabase_identity_service.dart';
import 'core/profile/shared_preferences_profile_repository.dart';
import 'features/journeys/data/drift_journey_repository.dart';
import 'features/premium/application/premium_entitlement_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = WonderlogDatabase();
  final controller = AppController(
    profileRepository: SharedPreferencesProfileRepository(),
    identityService: SupabaseIdentityService(AppConfig.current),
    premiumService: PremiumEntitlementService(),
  );
  await controller.initialize();

  runApp(
    WonderlogApp(
      controller: controller,
      journeyRepository: DriftJourneyRepository(database),
    ),
  );
}
