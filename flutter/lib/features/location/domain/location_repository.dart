import 'location_models.dart';

abstract interface class LocationRepository {
  Future<List<LocationPlace>> searchPlaces(String query);
  Future<LocationPlace?> reverseGeocode(
    double latitude,
    double longitude,
  );

  Stream<List<LocationPlace>> watchSavedPlaces();
  Future<void> savePlace(LocationPlace place);
  Future<void> deletePlace(String id);

  Stream<List<OfflineMapRegion>> watchOfflineRegions();
  Future<void> saveOfflineRegion(OfflineMapRegion region);
  Future<void> deleteOfflineRegion(String id);
}
