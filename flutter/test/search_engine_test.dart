import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/journeys/domain/journey.dart';
import 'package:wonderlog/features/search/domain/search_engine.dart';

void main() {
  test('search filters progressively and ignores accents', () {
    final journey = Journey(
      id: 'j',
      title: 'Casa di Anna',
      destination: 'Padova',
      country: 'Italia',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 2),
      description: '',
      latitude: 0,
      longitude: 0,
      favorite: false,
      archived: false,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    expect(
      WonderlogSearchEngine.search(
        query: 'casa',
        journeys: [journey],
        memories: const [],
      ),
      hasLength(1),
    );
    expect(
      WonderlogSearchEngine.search(
        query: 'Casa di Anna',
        journeys: [journey],
        memories: const [],
      ),
      hasLength(1),
    );
    expect(
      WonderlogSearchEngine.search(
        query: 'casa di marco',
        journeys: [journey],
        memories: const [],
      ),
      isEmpty,
    );
  });
}
