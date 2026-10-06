import '../../memories/domain/wonderlog_repository.dart';
import '../domain/premium_gate.dart';

final class PremiumBatchAllowance {
  const PremiumBatchAllowance({
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

final class PremiumAccessPolicy {
  PremiumAccessPolicy({
    required this.repository,
    required this.isPremium,
    this.gate = const PremiumGate(),
  });

  final WonderlogRepository repository;
  final bool Function() isPremium;
  final PremiumGate gate;

  bool get hasPremiumAccess => isPremium();

  int get journeyLimit => gate.journeyLimit(hasPremiumAccess);
  int get memoryLimit => gate.memoryLimit(hasPremiumAccess);
  int get albumPhotoLimit => gate.albumPhotoLimit(hasPremiumAccess);

  Future<PremiumGateResult> canCreateJourney() async {
    final active = await repository.watchJourneys().first;
    final archived = await repository.watchArchivedJourneys().first;
    final ownedJourneyIds = <String>{
      ...active.map((journey) => journey.id),
      ...archived.map((journey) => journey.id),
    };
    return gate.canCreateJourney(
      ownedJourneyIds.length,
      hasPremiumAccess,
    );
  }

  Future<PremiumGateResult> canCreateMemory({
    required String? journeyId,
  }) async {
    final memories = journeyId == null
        ? await repository.watchUnassignedMemories().first
        : await repository.watchMemories(journeyId).first;
    return canCreateMemoryForCount(memories.length);
  }

  PremiumGateResult canCreateMemoryForCount(int currentCount) =>
      gate.canCreateMemory(currentCount, hasPremiumAccess);

  PremiumBatchAllowance memoryCreationAllowanceForCount({
    required int currentCount,
    required int selectedCount,
  }) {
    final safeSelected = selectedCount < 0 ? 0 : selectedCount;
    final available = memoryLimit - currentCount;
    final slots = available < 0 ? 0 : available;
    final allowed = safeSelected < slots ? safeSelected : slots;
    return PremiumBatchAllowance(
      selectedCount: safeSelected,
      allowedCount: allowed,
      blockedCount: safeSelected - allowed,
      currentCount: currentCount,
      limit: memoryLimit,
    );
  }

  PhotoImportAllowance photoImportAllowance({
    required int currentCount,
    required int selectedCount,
  }) =>
      gate.calculatePhotoImportAllowance(
        currentCount,
        selectedCount,
        hasPremiumAccess,
      );

  PremiumGateResult canUseFeature(PremiumFeature feature) =>
      gate.canUseFeature(feature, hasPremiumAccess);
}
