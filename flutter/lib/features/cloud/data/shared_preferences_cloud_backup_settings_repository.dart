import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cloud_backup_config.dart';
import '../domain/cloud_backup_settings_repository.dart';

final class SharedPreferencesCloudBackupSettingsRepository
    implements CloudBackupSettingsRepository {
  static const _auto = 'cloud.automatic_backup_enabled';
  static const _wifi = 'cloud.wifi_only';
  static const _photos = 'cloud.include_photos';
  static const _battery = 'cloud.battery_not_low_only';
  static const _hours = 'cloud.periodic_interval_hours';
  static const _lastSuccess = 'cloud.last_successful_backup_at';
  static const _boundUserId = 'cloud.bound_user_id';

  final StreamController<CloudBackupSettings> _stream =
      StreamController<CloudBackupSettings>.broadcast();

  @override
  Stream<CloudBackupSettings> watchSettings() async* {
    yield await getSettings();
    yield* _stream.stream;
  }

  @override
  Future<CloudBackupSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return CloudBackupSettings(
      automaticBackupEnabled:
          prefs.getBool(_auto) ?? CloudBackupConfig.autoSyncEnabledDefault,
      wifiOnly:
          prefs.getBool(_wifi) ?? CloudBackupConfig.autoSyncWifiOnlyDefault,
      includePhotos: prefs.getBool(_photos) ?? true,
      batteryNotLowOnly: prefs.getBool(_battery) ?? true,
      periodicIntervalHours: _boundedHours(prefs.getInt(_hours) ?? 6),
    );
  }

  @override
  Future<void> setAutomaticBackupEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_auto, enabled);
    await _emit();
  }

  @override
  Future<void> setWifiOnly(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifi, enabled);
    await _emit();
  }

  @override
  Future<void> setIncludePhotos(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_photos, enabled);
    await _emit();
  }

  @override
  Future<void> setBatteryNotLowOnly(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_battery, enabled);
    await _emit();
  }

  @override
  Future<void> setPeriodicIntervalHours(int hours) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hours, _boundedHours(hours));
    await _emit();
  }

  @override
  Future<void> setLastSuccessfulBackupAt(DateTime? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_lastSuccess);
    } else {
      await prefs.setInt(
        _lastSuccess,
        value.toUtc().millisecondsSinceEpoch,
      );
    }
  }

  @override
  Future<DateTime?> getLastSuccessfulBackupAt() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_lastSuccess);
    return millis == null || millis <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  @override
  Future<String?> getBoundCloudUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_boundUserId)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  Future<void> setBoundCloudUserId(String userId) async {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User id is required.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_boundUserId, normalized);
  }

  int _boundedHours(int value) => value < 6 ? 6 : value;

  Future<void> _emit() async {
    if (!_stream.isClosed) _stream.add(await getSettings());
  }
}
