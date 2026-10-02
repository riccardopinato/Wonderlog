import 'app_profile.dart';

abstract interface class ProfileRepository {
  Future<AppProfile> load();
  Future<void> save(AppProfile profile);
}
