import '../../memories/domain/wonderlog_repository.dart';
import 'premium_gate.dart';

final class PremiumCreationLimitException implements Exception {
  const PremiumCreationLimitException(this.result);

  final PremiumLimitReached result;

  @override
  String toString() =>
      'PremiumCreationLimitException(${result.feature.name}, '
      '${result.current}/${result.limit})';
}

final class PremiumCreationGuard {
  const PremiumCreationGuard({
    required this.repository,
    required this.isPremium,
    this.gate = const PremiumGate(),
  });

  final WonderlogRepository repository;
  final bool Function() isPremium;
  final PremiumGate gate;

  Future<void> ensureJourneyAllowed() async {
    final count = await repository.countJourneys();
    final result = gate.canCreateJourney(count, isPremium());
    if (result is PremiumLimitReached) {
      throw PremiumCreationLimitException(result);
    }
  }

  Future<void> ensureMemoryAllowed({
    required String? journeyId,
  }) async {
    final result = await checkMemory(journeyId: journeyId);
    if (result is PremiumLimitReached) {
      throw PremiumCreationLimitException(result);
    }
  }

  Future<PremiumGateResult> checkMemory({
    required String? journeyId,
  }) async {
    final premium = isPremium();
    if (journeyId != null) {
      final count = await repository.countMemoriesForJourney(journeyId);
      return gate.canCreateJourneyMemory(count, premium);
    }

    final count = await repository.countUnassignedMemories();
    return gate.canCreateUnassignedMemory(count, premium);
  }

  Future<MemoryCreationAllowance> ensureMemoryBatchAllowed({
    required String? journeyId,
    required int requested,
  }) async {
    final allowance = await memoryAllowance(
      journeyId: journeyId,
      requested: requested,
    );
    _throwIfBlocked(allowance);
    return allowance;
  }

  void ensureNewJourneyMemoryBatchAllowed({
    required int requested,
  }) {
    final allowance = memoryAllowanceForNewJourney(requested: requested);
    _throwIfBlocked(allowance);
  }

  Future<MemoryCreationAllowance> memoryAllowance({
    required String? journeyId,
    required int requested,
  }) async {
    final premium = isPremium();
    if (journeyId != null) {
      final count = await repository.countMemoriesForJourney(journeyId);
      return gate.calculateMemoryCreationAllowance(
        current: count,
        requested: requested,
        premium: premium,
        unassigned: false,
      );
    }

    final count = await repository.countUnassignedMemories();
    return gate.calculateMemoryCreationAllowance(
      current: count,
      requested: requested,
      premium: premium,
      unassigned: true,
    );
  }

  MemoryCreationAllowance memoryAllowanceForNewJourney({
    required int requested,
  }) =>
      gate.calculateMemoryCreationAllowance(
        current: 0,
        requested: requested,
        premium: isPremium(),
        unassigned: false,
      );

  void _throwIfBlocked(MemoryCreationAllowance allowance) {
    if (allowance.blockedCount <= 0) return;
    throw PremiumCreationLimitException(
      PremiumLimitReached(
        feature: PremiumFeature.unlimitedMemories,
        current: allowance.currentCount,
        limit: allowance.limit,
      ),
    );
  }
}
