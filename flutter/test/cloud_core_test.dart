import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/cloud/domain/cloud_id_factory.dart';
import 'package:wonderlog/features/cloud/domain/cloud_merge_engine.dart';
import 'package:wonderlog/features/cloud/domain/cloud_sync_guard.dart';

void main() {
  test('cloud ids are stable for the same owner and local entity', () {
    expect(
      CloudIdFactory.journey('owner', 'journey'),
      CloudIdFactory.journey('owner', 'journey'),
    );
    expect(
      CloudIdFactory.journey('owner', 'journey'),
      isNot(CloudIdFactory.memory('owner', 'journey')),
    );
  });

  test('unsynced local edits are never silently overwritten', () {
    final decision = CloudMergeEngine.decide(
      localUpdatedAt: DateTime.utc(2026, 1, 1),
      localSyncStatus: 'PENDING_UPLOAD',
      cloudUpdatedAt: DateTime.utc(2026, 1, 2),
      cloudDeletedAt: null,
    );
    expect(decision, CloudMergeDecision.conflict);
  });

  test('manual sync requires auth and Premium, not automatic setting', () {
    expect(
      CloudSyncGuard.canSyncNow(
        authenticated: true,
        premium: true,
      ),
      isTrue,
    );
    expect(
      CloudSyncGuard.canSyncNow(
        authenticated: true,
        premium: false,
      ),
      isFalse,
    );
    expect(
      CloudSyncGuard.canSyncNow(
        authenticated: false,
        premium: true,
      ),
      isFalse,
    );
  });

  test('automatic backup additionally requires explicit setting', () {
    expect(
      CloudSyncGuard.canStartBackup(
        authenticated: true,
        premium: true,
        automaticBackupEnabled: true,
      ),
      isTrue,
    );
    expect(
      CloudSyncGuard.canStartBackup(
        authenticated: true,
        premium: false,
        automaticBackupEnabled: true,
      ),
      isFalse,
    );
  });
}
