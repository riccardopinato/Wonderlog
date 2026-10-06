import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/cloud_restore_repository.dart';
import '../domain/cloud_backup_config.dart';
import '../domain/cloud_backup_settings_repository.dart';
import '../domain/cloud_models.dart';
import '../domain/cloud_provider.dart';
import '../domain/cloud_sync_guard.dart';
import '../domain/cloud_sync_repository.dart';
import '../domain/restore_models.dart';
import '../domain/sync_queue_store.dart';

enum CloudRuntimeBlockReason {
  signedOut,
  premiumRequired,
  busy,
}

final class CloudRuntimeException implements Exception {
  const CloudRuntimeException(this.reason, this.message);

  final CloudRuntimeBlockReason reason;
  final String message;

  @override
  String toString() => message;
}

final class CloudRuntimeController extends ChangeNotifier {
  CloudRuntimeController({
    required this.cloudProvider,
    required this.syncRepository,
    required this.restoreRepository,
    required this.settingsRepository,
    required this.queueStore,
    required this.isPremium,
  });

  final CloudProvider cloudProvider;
  final CloudSyncRepository syncRepository;
  final CloudRestoreRepository restoreRepository;
  final CloudBackupSettingsRepository settingsRepository;
  final SyncQueueStore queueStore;
  final bool Function() isPremium;

  CloudBackupSettings _settings = const CloudBackupSettings();
  DateTime? _lastSuccessfulBackupAt;
  int _pendingCount = 0;
  bool _syncing = false;
  bool _restoring = false;
  SyncSummary? _lastSyncSummary;
  RestoreSummary? _lastRestoreSummary;
  RestoreProgress? _restoreProgress;
  String? _lastError;

  StreamSubscription<CloudBackupSettings>? _settingsSubscription;
  StreamSubscription<int>? _queueSubscription;

  CloudBackupSettings get settings => _settings;
  DateTime? get lastSuccessfulBackupAt => _lastSuccessfulBackupAt;
  int get pendingCount => _pendingCount;
  bool get syncing => _syncing;
  bool get restoring => _restoring;
  bool get busy => _syncing || _restoring;
  SyncSummary? get lastSyncSummary => _lastSyncSummary;
  RestoreSummary? get lastRestoreSummary => _lastRestoreSummary;
  RestoreProgress? get restoreProgress => _restoreProgress;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    _settings = await settingsRepository.getSettings();
    if (_settings.automaticBackupEnabled) {
      // Step 25 certifies manual sync/restore first. Keep legacy persisted
      // automatic settings off until the background scheduler is certified.
      await settingsRepository.setAutomaticBackupEnabled(false);
      _settings = await settingsRepository.getSettings();
    }
    _lastSuccessfulBackupAt =
        await settingsRepository.getLastSuccessfulBackupAt();
    _pendingCount = await syncRepository.pendingCount();

    _settingsSubscription =
        settingsRepository.watchSettings().listen((value) {
      _settings = value;
      notifyListeners();
    });
    _queueSubscription = queueStore.watchPendingCount().listen((value) {
      _pendingCount = value;
      notifyListeners();
    });
  }

  Future<bool> isAuthenticated() => cloudProvider.isAuthenticated();

  Future<SyncSummary> syncNow() async {
    await _requireManualSyncAccess();
    if (busy) {
      throw const CloudRuntimeException(
        CloudRuntimeBlockReason.busy,
        'A cloud operation is already running.',
      );
    }

    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final currentSettings = await settingsRepository.getSettings();
      final summary = await syncRepository.syncAllPending(
        includePhotos: currentSettings.includePhotos,
      );
      _lastSyncSummary = summary;
      _pendingCount = await syncRepository.pendingCount();

      if (summary.failures == 0) {
        final now = DateTime.now().toUtc();
        await settingsRepository.setLastSuccessfulBackupAt(now);
        _lastSuccessfulBackupAt = now;
      } else {
        _lastError = 'Cloud sync completed with ' +
            summary.failures.toString() +
            ' failed operation(s).';
      }
      return summary;
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<RestoreSummary> restoreNow() async {
    await _requireRestoreAccess();
    if (busy) {
      throw const CloudRuntimeException(
        CloudRuntimeBlockReason.busy,
        'A cloud operation is already running.',
      );
    }

    _restoring = true;
    _restoreProgress = const RestoreProgress(
      phase: RestorePhase.preparing,
      message: 'Preparing cloud restore…',
    );
    _lastError = null;
    notifyListeners();

    try {
      final summary = await restoreRepository.restoreEverything(
        onProgress: (progress) async {
          _restoreProgress = progress;
          notifyListeners();
        },
      );
      _lastRestoreSummary = summary;
      if (summary.failures > 0) {
        _lastError = 'Restore completed with ' +
            summary.failures.toString() +
            ' failed item(s).';
      }
      return summary;
    } catch (error) {
      _lastError = error.toString();
      rethrow;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  Future<void> setIncludePhotos(bool value) =>
      settingsRepository.setIncludePhotos(value);

  Future<void> setAutomaticBackupEnabled(bool value) =>
      settingsRepository.setAutomaticBackupEnabled(value);

  Future<void> _requireManualSyncAccess() async {
    final authenticated = await cloudProvider.isAuthenticated();
    if (!authenticated) {
      throw const CloudRuntimeException(
        CloudRuntimeBlockReason.signedOut,
        'Sign in before using cloud backup.',
      );
    }
    if (!CloudSyncGuard.canSyncNow(
      authenticated: authenticated,
      premium: isPremium(),
    )) {
      throw const CloudRuntimeException(
        CloudRuntimeBlockReason.premiumRequired,
        'Cloud backup requires Wonderlog Premium.',
      );
    }
  }

  Future<void> _requireRestoreAccess() async {
    final authenticated = await cloudProvider.isAuthenticated();
    if (!authenticated) {
      throw const CloudRuntimeException(
        CloudRuntimeBlockReason.signedOut,
        'Sign in before restoring cloud data.',
      );
    }
    if (!CloudSyncGuard.canRestore(
      authenticated: authenticated,
      premium: isPremium(),
    )) {
      throw const CloudRuntimeException(
        CloudRuntimeBlockReason.premiumRequired,
        'Cloud restore requires Wonderlog Premium.',
      );
    }
  }

  @override
  void dispose() {
    _settingsSubscription?.cancel();
    _queueSubscription?.cancel();
    super.dispose();
  }
}
