final class SubscriptionLimits {
  const SubscriptionLimits({
    required this.albumPhotosLimit,
    required this.memoriesLimit,
    required this.journeysLimit,
  });

  final int albumPhotosLimit;
  final int memoriesLimit;
  final int journeysLimit;
}

abstract final class SubscriptionConfig {
  static const freeJourneysLimit = 3;
  static const freeAlbumPhotosPerJourney = 5;
  static const premiumAlbumPhotosPerJourney = 100;
  static const freeMemoriesPerJourney = 5;
  static const freeUnassignedMemories = freeMemoriesPerJourney;
  static const premiumJourneysLimit = 0x7fffffff;
  static const premiumMemoriesPerJourney = 0x7fffffff;

  static const freeCloudBackup = false;
  static const premiumCloudBackup = true;
  static const freePdfExport = false;
  static const premiumPdfExport = true;
  static const freeOfflineMaps = false;
  static const premiumOfflineMaps = true;
  static const freePremiumThemes = false;
  static const premiumPremiumThemes = true;
  static const freeAdvancedStats = false;
  static const premiumAdvancedStats = true;

  static const premiumEntitlementId = 'premium';

  static const freeLimits = SubscriptionLimits(
    albumPhotosLimit: freeAlbumPhotosPerJourney,
    memoriesLimit: freeMemoriesPerJourney,
    journeysLimit: freeJourneysLimit,
  );

  static const premiumLimits = SubscriptionLimits(
    albumPhotosLimit: premiumAlbumPhotosPerJourney,
    memoriesLimit: premiumMemoriesPerJourney,
    journeysLimit: premiumJourneysLimit,
  );

  static SubscriptionLimits limits(bool isPremium) =>
      isPremium ? premiumLimits : freeLimits;
}
