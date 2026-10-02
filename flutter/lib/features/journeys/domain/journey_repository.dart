import 'journey.dart';

abstract interface class JourneyRepository {
  Stream<List<Journey>> watchJourneys();

  Future<Journey> createJourney({
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    String country = '',
    String description = '',
  });
}
