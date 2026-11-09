import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/journeys/domain/trip_planner_template.dart';

void main() {
  test('Trip Planner produces only selected editorial description headings', () {
    final full = buildTripPlannerDescription(
      ideasHeading: 'Idee per le tappe',
      packingHeading: 'Bagaglio essenziale',
      includeIdeas: true,
      includePacking: true,
    );
    expect(full, contains('## Idee per le tappe'));
    expect(full, contains('## Bagaglio essenziale'));

    final noPacking = buildTripPlannerDescription(
      ideasHeading: 'Idee per le tappe',
      packingHeading: 'Bagaglio essenziale',
      includeIdeas: true,
      includePacking: false,
    );
    expect(noPacking, isNot(contains('Bagaglio essenziale')));
    expect(
      buildTripPlannerDescription(
        ideasHeading: 'Idee',
        packingHeading: 'Bagagli',
        includeIdeas: false,
        includePacking: false,
      ),
      isEmpty,
    );
  });
}
