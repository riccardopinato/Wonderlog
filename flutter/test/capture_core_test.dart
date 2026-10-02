import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/capture/domain/capture_models.dart';
import 'package:wonderlog/features/capture/domain/capture_validator.dart';
import 'package:wonderlog/features/capture/domain/shared_location_parser.dart';

void main() {
  test('capture text requires a memory destination', () {
    const item = CaptureIncomingItem(
      id: '1',
      type: CaptureContentType.text,
      text: 'hello',
    );
    const draft = CaptureDraft(
      items: [item],
      journeyId: 'journey',
    );

    expect(CaptureValidator.validate(draft).valid, isFalse);
  });

  test('capture text accepts a new memory destination', () {
    const item = CaptureIncomingItem(
      id: '1',
      type: CaptureContentType.text,
      text: 'hello',
    );
    const draft = CaptureDraft(
      items: [item],
      journeyId: 'journey',
      createNewMemory: true,
      memoryTitle: 'Moment',
    );

    expect(CaptureValidator.validate(draft).valid, isTrue);
  });

  test('shared map coordinates are parsed deterministically', () {
    final location = SharedLocationParser.parse(
      'https://maps.example/?q=46.919,11.955',
    );
    expect(location?.latitude, 46.919);
    expect(location?.longitude, 11.955);
  });
}
