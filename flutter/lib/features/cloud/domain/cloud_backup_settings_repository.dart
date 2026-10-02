import 'cloud_backup_config.dart';

abstract interface class CloudBackupSettingsRepository {
  Stream<CloudBackupSettings> watchSettings();
  Future<CloudBackupSettings> getSettings();

  Future<void> setAutomaticBackupEnabled(bool enabled);
  Future<void> setWifiOnly(bool enabled);
  Future<void> setIncludePhotos(bool enabled);
  Future<void> setBatteryNotLowOnly(bool enabled);
  Future<void> setPeriodicIntervalHours(int hours);
  Future<void> setLastSuccessfulBackupAt(DateTime? value);
  Future<DateTime?> getLastSuccessfulBackupAt();
}
