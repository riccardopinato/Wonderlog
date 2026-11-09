import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/journeys/domain/trip_planner_template.dart';

void main() {
  test('Empty headings are omitted instead of creating blank sections', () {
    final result = buildTripPlannerDescription(
      ideasHeading: '   ',
      packingHeading: '  Bagagli   ',
      includeIdeas: true,
      includePacking: true,
    );
    expect(result, '## Bagagli');
    expect(
      buildTripPlannerDescription(
        ideasHeading: '  ',
        packingHeading: '',
        includeIdeas: true,
        includePacking: true,
      ),
      isEmpty,
    );
  });

  test('The wizard keeps Premium and confirmation guards ahead of the writer',
      () {
    final source = File(
      'lib/features/journeys/presentation/journey_widgets.dart',
    ).readAsStringSync();
    final start = source.indexOf('Future<void> showCreateJourneyDialog(');
    final end = source.indexOf('Future<void> showEditJourneyDialog(');
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final wizard = source.substring(start, end);
    expect(wizard, contains('barrierDismissible: false'));
    expect(wizard, contains('endDate.isBefore(startDate)'));
    expect(wizard, contains('onPressed: saving'));
    expect(wizard, contains('confirmed != true'));
    expect(wizard, contains('canCreateJourney()'));
    expect(wizard, contains('description: description'));
    final confirmation = wizard.indexOf('confirmed != true');
    final gate = wizard.lastIndexOf('canCreateJourney()');
    final write = wizard.indexOf('await repository.createJourney(');
    expect(confirmation, lessThan(gate));
    expect(gate, lessThan(write));
    expect(wizard.substring(write).contains('createJourney('), isTrue);
  });

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
