import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/database/wonderlog_database.dart' as db;
import '../domain/location_models.dart';
import '../domain/location_repository.dart';

final class OpenStreetMapRepository implements LocationRepository {
  OpenStreetMapRepository(
    this.database, {
    http.Client? client,
    String Function()? localeTag,
  })  : client = client ?? http.Client(),
        localeTag = localeTag ?? (() => 'en');

  static const userAgent =
      'Wonderlog/1.0 (com.riccardopinato.wonderlog)';

  final db.WonderlogDatabase database;
  final http.Client client;
  final String Function() localeTag;
  final Uuid _uuid = const Uuid();

  Future<void> _requestGate = Future<void>.value();
  DateTime? _lastNetworkRequestAt;

  @override
  Future<List<LocationPlace>> searchPlaces(String query) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final locale = _normalizedLocale();
    final cacheKey = _cacheKey('search', locale, normalized);
    final cached = await (database.select(database.geocodingCache)
          ..where((row) => row.query.equals(cacheKey)))
        .getSingleOrNull();
    if (cached != null) {
      return [_placeFromCache(cached)];
    }

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/search',
      {
        'q': normalized,
        'format': 'json',
        'limit': '5',
        'addressdetails': '1',
        'accept-language': locale,
      },
    );

    try {
      await _waitForNominatimSlot();
      final response = await client
          .get(
            uri,
            headers: {
              'User-Agent': userAgent,
              'Accept-Language': locale,
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      final result = <LocationPlace>[];
      for (final raw in decoded) {
        if (raw is! Map) continue;
        final map = Map<String, Object?>.from(raw);
        final latitude = double.tryParse(map['lat']?.toString() ?? '');
        final longitude = double.tryParse(map['lon']?.toString() ?? '');
        if (latitude == null || longitude == null) continue;
        final displayName = map['display_name']?.toString() ?? '';
        final address = map['address'] is Map
            ? Map<String, Object?>.from(map['address']! as Map)
            : const <String, Object?>{};

        final city = _firstNonBlank([
          address['city'],
          address['town'],
          address['village'],
          address['municipality'],
          address['attraction'],
          address['tourism'],
          displayName.split(',').firstOrNull,
        ]);
        final country = address['country']?.toString() ?? '';
        final region = _firstNonBlank([
          address['state'],
          address['county'],
          address['region'],
        ]);

        final place = LocationPlace(
          id: _uuid.v4(),
          displayName: displayName,
          country: country,
          city: city,
          region: region,
          latitude: latitude,
          longitude: longitude,
          source: 'NOMINATIM',
        );
        result.add(place);

        if (result.length == 1) {
          await database.into(database.geocodingCache).insertOnConflictUpdate(
                db.GeocodingCacheCompanion.insert(
                  query: cacheKey,
                  displayName: displayName,
                  country: Value(country),
                  city: Value(city),
                  region: Value(region),
                  latitude: latitude,
                  longitude: longitude,
                  cachedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
                ),
              );
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<LocationPlace?> reverseGeocode(
    double latitude,
    double longitude,
  ) async {
    final locale = _normalizedLocale();
    final coordinateKey = latitude.toStringAsFixed(6) +
        ',' +
        longitude.toStringAsFixed(6);
    final cacheKey = _cacheKey('reverse', locale, coordinateKey);

    final cached = await (database.select(database.geocodingCache)
          ..where((row) => row.query.equals(cacheKey)))
        .getSingleOrNull();
    if (cached != null) return _placeFromCache(cached);

    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'json',
        'addressdetails': '1',
        'accept-language': locale,
      },
    );

    try {
      await _waitForNominatimSlot();
      final response = await client
          .get(
            uri,
            headers: {
              'User-Agent': userAgent,
              'Accept-Language': locale,
            },
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final raw = jsonDecode(response.body);
      if (raw is! Map) return null;
      final map = Map<String, Object?>.from(raw);
      final displayName = map['display_name']?.toString() ?? '';
      final address = map['address'] is Map
          ? Map<String, Object?>.from(map['address']! as Map)
          : const <String, Object?>{};

      final city = _firstNonBlank([
        address['city'],
        address['town'],
        address['village'],
        address['municipality'],
      ]);
      final country = address['country']?.toString() ?? '';
      final region = _firstNonBlank([
        address['state'],
        address['county'],
        address['region'],
      ]);

      await database.into(database.geocodingCache).insertOnConflictUpdate(
            db.GeocodingCacheCompanion.insert(
              query: cacheKey,
              displayName: displayName,
              country: Value(country),
              city: Value(city),
              region: Value(region),
              latitude: latitude,
              longitude: longitude,
              cachedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
            ),
          );

      return LocationPlace(
        id: _uuid.v4(),
        displayName: displayName,
        country: country,
        city: city,
        region: region,
        latitude: latitude,
        longitude: longitude,
        source: 'NOMINATIM',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<LocationPlace>> watchSavedPlaces() {
    final query = database.select(database.locationPlaces)
      ..orderBy([(row) => OrderingTerm.asc(row.displayName)]);
    return query.watch().map(
          (rows) => rows
              .map(
                (row) => LocationPlace(
                  id: row.id,
                  displayName: row.displayName,
                  country: row.country,
                  city: row.city,
                  region: row.region,
                  latitude: row.latitude,
                  longitude: row.longitude,
                  source: row.source,
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> savePlace(LocationPlace place) =>
      database.into(database.locationPlaces).insertOnConflictUpdate(
            db.LocationPlacesCompanion.insert(
              id: place.id,
              displayName: place.displayName,
              country: Value(place.country),
              city: Value(place.city),
              region: Value(place.region),
              latitude: place.latitude,
              longitude: place.longitude,
              source: place.source,
            ),
          );

  @override
  Future<void> deletePlace(String id) async {
    await (database.delete(database.locationPlaces)
          ..where((row) => row.id.equals(id)))
        .go();
  }

  @override
  Stream<List<OfflineMapRegion>> watchOfflineRegions() {
    final query = database.select(database.offlineMapRegions)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.watch().map(
          (rows) => rows
              .map(
                (row) => OfflineMapRegion(
                  id: row.id,
                  name: row.name,
                  centerLatitude: row.centerLatitude,
                  centerLongitude: row.centerLongitude,
                  radiusKm: row.radiusKm,
                  zoomMin: row.zoomMin,
                  zoomMax: row.zoomMax,
                  sizeBytes: row.sizeBytes,
                  isDownloaded: row.isDownloaded,
                  downloadProgress: row.downloadProgress,
                  createdAt: DateTime.fromMillisecondsSinceEpoch(
                    row.createdAt,
                    isUtc: true,
                  ),
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> saveOfflineRegion(OfflineMapRegion region) =>
      database.into(database.offlineMapRegions).insertOnConflictUpdate(
            db.OfflineMapRegionsCompanion.insert(
              id: region.id,
              name: region.name,
              centerLatitude: region.centerLatitude,
              centerLongitude: region.centerLongitude,
              radiusKm: region.radiusKm,
              zoomMin: region.zoomMin,
              zoomMax: region.zoomMax,
              sizeBytes: Value(region.sizeBytes),
              isDownloaded: Value(region.isDownloaded),
              downloadProgress: Value(region.downloadProgress),
              createdAt: region.createdAt.toUtc().millisecondsSinceEpoch,
            ),
          );

  @override
  Future<void> deleteOfflineRegion(String id) async {
    await (database.delete(database.offlineMapRegions)
          ..where((row) => row.id.equals(id)))
        .go();
  }

  LocationPlace _placeFromCache(db.GeocodingCacheData cached) =>
      LocationPlace(
        id: _uuid.v4(),
        displayName: cached.displayName,
        country: cached.country,
        city: cached.city,
        region: cached.region,
        latitude: cached.latitude,
        longitude: cached.longitude,
        source: 'CACHED',
      );

  String _normalizedLocale() {
    final raw = localeTag().trim();
    if (raw.isEmpty) return 'en';
    return raw.replaceAll('_', '-');
  }

  String _cacheKey(String kind, String locale, String value) =>
      'v2|$kind|${locale.toLowerCase()}|${value.toLowerCase()}';

  Future<void> _waitForNominatimSlot() {
    final completer = Completer<void>();
    _requestGate = _requestGate.then((_) async {
      final last = _lastNetworkRequestAt;
      if (last != null) {
        final elapsed = DateTime.now().difference(last);
        const minimum = Duration(seconds: 1);
        if (elapsed < minimum) {
          await Future<void>.delayed(minimum - elapsed);
        }
      }
      _lastNetworkRequestAt = DateTime.now();
      completer.complete();
    });
    return completer.future;
  }

  String _firstNonBlank(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return '';
  }
}
