import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/premium/domain/premium_gate.dart';

void main() {
  const gate = PremiumGate();

  test('free journeys stop at the configured limit', () {
    expect(gate.canCreateJourney(2, false), isA<PremiumAllowed>());
    expect(gate.canCreateJourney(3, false), isA<PremiumLimitReached>());
  });

  test('photo allowance keeps partial imports deterministic', () {
    final allowance = gate.calculatePhotoImportAllowance(3, 5, false);
    expect(allowance.allowedCount, 2);
    expect(allowance.blockedCount, 3);
    expect(allowance.isFullyAllowed, isFalse);
  });

  test('premium unlocks gated feature flags', () {
    expect(
      gate.canUseFeature(PremiumFeature.cloudBackup, true),
      isA<PremiumAllowed>(),
    );
    expect(
      gate.canUseFeature(PremiumFeature.cloudBackup, false),
      isA<PremiumRequired>(),
    );
  });

  test('Journey and unassigned Memory buckets are explicit and independent', () {
    expect(gate.canCreateJourneyMemory(4, false), isA<PremiumAllowed>());
    expect(gate.canCreateJourneyMemory(5, false), isA<PremiumLimitReached>());
    expect(gate.canCreateUnassignedMemory(4, false), isA<PremiumAllowed>());
    expect(
      gate.canCreateUnassignedMemory(5, false),
      isA<PremiumLimitReached>(),
    );

    final allowance = gate.calculateMemoryCreationAllowance(
      current: 3,
      requested: 4,
      premium: false,
      unassigned: true,
    );
    expect(allowance.allowedCount, 2);
    expect(allowance.blockedCount, 2);
  });

}
