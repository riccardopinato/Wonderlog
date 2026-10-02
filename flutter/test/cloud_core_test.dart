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

  test('backup requires auth premium and explicit automatic setting', () {
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
