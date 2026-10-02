import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/smart_journey/domain/geo_math.dart';
import 'package:wonderlog/features/smart_journey/domain/smart_journey_draft_editor.dart';
import 'package:wonderlog/features/smart_journey/domain/smart_journey_models.dart';
import 'package:wonderlog/features/smart_journey/domain/smart_journey_reconstruction_engine.dart';

void main() {
  test('geo distance is near zero for equal coordinates', () {
    expect(GeoMath.distanceMeters(46, 11, 46, 11), lessThan(0.01));
  });

  test('reconstruction groups photos into days and stops', () async {
    final engine = SmartJourneyReconstructionEngine();
    final photos = [
      SmartJourneySourcePhoto(
        sourceUri: 'a',
        originalIndex: 0,
        capturedAt: DateTime(2026, 8, 10, 9),
        latitude: 46.919,
        longitude: 11.955,
        placeLabel: 'Campo Tures',
      ),
      SmartJourneySourcePhoto(
        sourceUri: 'b',
        originalIndex: 1,
        capturedAt: DateTime(2026, 8, 10, 10),
        latitude: 46.920,
        longitude: 11.956,
        placeLabel: 'Campo Tures',
      ),
    ];

    final draft = await engine.reconstruct(
      photos,
      resolvePlace: (_, _) async => 'Campo Tures',
    );

    expect(draft.days, hasLength(1));
    expect(draft.stopCount, 1);
    expect(draft.destination, 'Campo Tures');
    expect(draft.photos, hasLength(2));
  });

  test('draft editor excludes photos without deleting them', () async {
    final engine = SmartJourneyReconstructionEngine();
    final draft = await engine.reconstruct(
      [
        SmartJourneySourcePhoto(
          sourceUri: 'a',
          originalIndex: 0,
          capturedAt: DateTime(2026, 8, 10),
        ),
      ],
      resolvePlace: (_, _) async => null,
    );

    final updated = SmartJourneyDraftEditor.setPhotoIncluded(
      draft,
      draft.photos.single.id,
      false,
    );

    expect(updated.photos.single.included, isFalse);
    expect(updated.excludedPhotoCount, 1);
  });
}
