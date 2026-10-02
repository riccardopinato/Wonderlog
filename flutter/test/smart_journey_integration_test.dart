import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/smart_journey/domain/smart_journey_creation_policy.dart';

void main() {
  test('Smart Journey creation policy keeps free photo allowance', () {
    const policy = SmartJourneyCreationPolicy();
    final allowance = policy.evaluate(
      currentJourneyCount: 1,
      selectedPhotoCount: 8,
      isPremium: false,
    );
    expect(allowance.journeyCreationAllowed, isTrue);
    expect(allowance.allowedPhotoCount, 5);
    expect(allowance.blockedPhotoCount, 3);
  });
}
