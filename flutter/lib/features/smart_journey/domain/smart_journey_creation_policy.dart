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

    return SmartJourneyCreationAllowance(
      isPremium: isPremium,
      journeyCreationAllowed: journeyGate is PremiumAllowed,
      selectedPhotoCount: selectedPhotoCount,
      allowedPhotoCount: photos.allowedCount,
      blockedPhotoCount: photos.blockedCount,
    );
  }
}
