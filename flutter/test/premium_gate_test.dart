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

  test('Premium unlocks only capabilities that are actually shipped', () {
    expect(
      gate.canUseFeature(PremiumFeature.pdfExport, true),
      isA<PremiumAllowed>(),
    );
    expect(
      gate.canUseFeature(PremiumFeature.pdfExport, false),
      isA<PremiumRequired>(),
    );
    expect(
      gate.canUseFeature(PremiumFeature.cloudBackup, true),
      isA<PremiumRequired>(),
    );
    expect(
      gate.canUseFeature(PremiumFeature.offlineMaps, true),
      isA<PremiumRequired>(),
    );
  });
}
