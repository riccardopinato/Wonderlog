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
    final journeys = await repository.watchJourneys().first;
    final result = gate.canCreateJourney(journeys.length, isPremium());
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
      final memories = await repository.watchMemories(journeyId).first;
      return gate.canCreateJourneyMemory(memories.length, premium);
    }

    final memories = await repository.watchAllMemories().first;
    final unassigned =
        memories.where((memory) => memory.journeyId == null).length;
    return gate.canCreateUnassignedMemory(unassigned, premium);
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
      final memories = await repository.watchMemories(journeyId).first;
      return gate.calculateMemoryCreationAllowance(
        current: memories.length,
        requested: requested,
        premium: premium,
        unassigned: false,
      );
    }

    final memories = await repository.watchAllMemories().first;
    final unassigned =
        memories.where((memory) => memory.journeyId == null).length;
    return gate.calculateMemoryCreationAllowance(
      current: unassigned,
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
