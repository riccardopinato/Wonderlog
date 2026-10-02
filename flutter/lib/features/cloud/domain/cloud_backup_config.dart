abstract final class CloudBackupConfig {
  static const maxRetryCount = 5;
  static const initialRetryDelay = Duration(seconds: 5);
  static const autoSyncWifiOnlyDefault = true;
  static const autoSyncEnabledDefault = true;
  static const syncBatchSize = 25;
  static const photoUploadBatchSize = 5;
  static const cloudSchemaVersion = 1;
}

final class CloudBackupSettings {
  const CloudBackupSettings({
    this.automaticBackupEnabled = CloudBackupConfig.autoSyncEnabledDefault,
    this.wifiOnly = CloudBackupConfig.autoSyncWifiOnlyDefault,
    this.includePhotos = true,
    this.batteryNotLowOnly = true,
    this.periodicIntervalHours = 6,
  });

  final bool automaticBackupEnabled;
  final bool wifiOnly;
  final bool includePhotos;
  final bool batteryNotLowOnly;
  final int periodicIntervalHours;
}
