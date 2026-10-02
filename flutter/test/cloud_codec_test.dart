import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/cloud/domain/cloud_codec.dart';
import 'package:wonderlog/features/cloud/domain/cloud_models.dart';

void main() {
  test('cloud journey codec preserves Kotlin millisecond timestamps', () {
    final value = CloudJourney(
      id: 'c1',
      ownerId: 'u1',
      localReferenceId: 'j1',
      title: 'Trip',
      destination: 'Place',
      country: 'IT',
      description: '',
      startDate: '2026-08-10',
      endDate: '2026-08-14',
      accentTheme: 'Preset_0',
      coverPhotoCloudId: null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
    );

    final json = CloudCodec.journeyToJson(value);
    expect(json['created_at'], 1000);
    expect(json['updated_at'], 2000);

    final restored = CloudCodec.journeyFromJson(
      Map<String, dynamic>.from(json),
    );
    expect(restored.localReferenceId, 'j1');
    expect(restored.updatedAt.millisecondsSinceEpoch, 2000);
  });
}
