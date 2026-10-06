import '../../premium/domain/premium_gate.dart';
import 'smart_journey_models.dart';

final class SmartJourneyCreationPolicy {
  const SmartJourneyCreationPolicy({
    this.premiumGate = const PremiumGate(),
  });

  final PremiumGate premiumGate;

  SmartJourneyCreationAllowance evaluate({
    required int currentJourneyCount,
    required int selectedPhotoCount,
    required bool isPremium,
    int selectedMemoryCount = 0,
  }) {
    final journeyGate = premiumGate.canCreateJourney(
      currentJourneyCount,
      isPremium,
    );
    final photos = premiumGate.calculatePhotoImportAllowance(
      0,
      selectedPhotoCount,
      isPremium,
    );
    final memoryLimit = premiumGate.memoryLimit(isPremium);
    final safeMemoryCount = selectedMemoryCount < 0 ? 0 : selectedMemoryCount;
    final allowedMemoryCount =
        safeMemoryCount < memoryLimit ? safeMemoryCount : memoryLimit;

    return SmartJourneyCreationAllowance(
      isPremium: isPremium,
      journeyCreationAllowed: journeyGate is PremiumAllowed,
      selectedPhotoCount: selectedPhotoCount,
      allowedPhotoCount: photos.allowedCount,
      blockedPhotoCount: photos.blockedCount,
      selectedMemoryCount: safeMemoryCount,
      allowedMemoryCount: allowedMemoryCount,
      blockedMemoryCount: safeMemoryCount - allowedMemoryCount,
    );
  }
}
