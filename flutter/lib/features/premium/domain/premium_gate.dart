import 'subscription_config.dart';

enum PremiumFeature {
  unlimitedJourneys,
  extendedAlbum,
  unlimitedMemories,
  cloudBackup,
  pdfExport,
  offlineMaps,
  premiumThemes,
  advancedStatistics,
}

sealed class PremiumGateResult {
  const PremiumGateResult();
}

final class PremiumAllowed extends PremiumGateResult {
  const PremiumAllowed();
}

final class PremiumLimitReached extends PremiumGateResult {
  const PremiumLimitReached({
    required this.feature,
    required this.current,
    required this.limit,
  });

  final PremiumFeature feature;
  final int current;
  final int limit;
}

final class PremiumRequired extends PremiumGateResult {
  const PremiumRequired(this.feature);
  final PremiumFeature feature;
}

final class PhotoImportAllowance {
  const PhotoImportAllowance({
    required this.selectedCount,
    required this.allowedCount,
    required this.blockedCount,
    required this.currentCount,
    required this.limit,
  });

  final int selectedCount;
  final int allowedCount;
  final int blockedCount;
  final int currentCount;
  final int limit;

  bool get isFullyAllowed => blockedCount == 0;
}

final class PremiumGate {
  const PremiumGate();

  int journeyLimit(bool premium) =>
      SubscriptionConfig.limits(premium).journeysLimit;

  int albumPhotoLimit(bool premium) =>
      SubscriptionConfig.limits(premium).albumPhotosLimit;

  int memoryLimit(bool premium) =>
      SubscriptionConfig.limits(premium).memoriesLimit;

  PremiumGateResult canCreateJourney(int current, bool premium) {
    final limit = journeyLimit(premium);
    return current < limit
        ? const PremiumAllowed()
        : PremiumLimitReached(
            feature: PremiumFeature.unlimitedJourneys,
            current: current,
            limit: limit,
          );
  }

  PremiumGateResult canAddAlbumPhotos(
    int current,
    int photosToAdd,
    bool premium,
  ) {
    final limit = albumPhotoLimit(premium);
    return current + photosToAdd <= limit
        ? const PremiumAllowed()
        : PremiumLimitReached(
            feature: PremiumFeature.extendedAlbum,
            current: current,
            limit: limit,
          );
  }

  PhotoImportAllowance calculatePhotoImportAllowance(
    int current,
    int selected,
    bool premium,
  ) {
    final limit = albumPhotoLimit(premium);
    final safeSelected = selected < 0 ? 0 : selected;
    final available = limit - current;
    final slots = available < 0 ? 0 : available;
    final allowed = safeSelected < slots ? safeSelected : slots;
    return PhotoImportAllowance(
      selectedCount: safeSelected,
      allowedCount: allowed,
      blockedCount: safeSelected - allowed,
      currentCount: current,
      limit: limit,
    );
  }

  PremiumGateResult canCreateMemory(int current, bool premium) {
    final limit = memoryLimit(premium);
    return current < limit
        ? const PremiumAllowed()
        : PremiumLimitReached(
            feature: PremiumFeature.unlimitedMemories,
            current: current,
            limit: limit,
          );
  }

  bool hasFeature(PremiumFeature feature, bool premium) {
    if (premium) return true;
    return switch (feature) {
      PremiumFeature.unlimitedJourneys => false,
      PremiumFeature.extendedAlbum => false,
      PremiumFeature.unlimitedMemories => false,
      PremiumFeature.cloudBackup => SubscriptionConfig.freeCloudBackup,
      PremiumFeature.pdfExport => SubscriptionConfig.freePdfExport,
      PremiumFeature.offlineMaps => SubscriptionConfig.freeOfflineMaps,
      PremiumFeature.premiumThemes => SubscriptionConfig.freePremiumThemes,
      PremiumFeature.advancedStatistics => SubscriptionConfig.freeAdvancedStats,
    };
  }

  PremiumGateResult canUseFeature(PremiumFeature feature, bool premium) =>
      hasFeature(feature, premium)
          ? const PremiumAllowed()
          : PremiumRequired(feature);
}
