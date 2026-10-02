abstract final class CloudSyncGuard {
  static bool canStartBackup({
    required bool authenticated,
    required bool premium,
    required bool automaticBackupEnabled,
  }) =>
      authenticated && premium && automaticBackupEnabled;

  static bool canRestore({
    required bool authenticated,
    required bool premium,
  }) =>
      authenticated && premium;
}
