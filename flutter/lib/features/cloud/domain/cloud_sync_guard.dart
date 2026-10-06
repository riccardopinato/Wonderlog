abstract final class CloudSyncGuard {
  static bool canSyncNow({
    required bool authenticated,
    required bool premium,
  }) =>
      authenticated && premium;

  static bool canStartBackup({
    required bool authenticated,
    required bool premium,
    required bool automaticBackupEnabled,
  }) =>
      canSyncNow(authenticated: authenticated, premium: premium) &&
      automaticBackupEnabled;

  static bool canRestore({
    required bool authenticated,
    required bool premium,
  }) =>
      authenticated && premium;
}
