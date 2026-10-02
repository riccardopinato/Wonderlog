enum CloudMergeDecision {
  insertCloud,
  applyCloud,
  keepLocal,
  conflict,
  skip,
}

abstract final class CloudMergeEngine {
  static CloudMergeDecision decide({
    required DateTime? localUpdatedAt,
    required String? localSyncStatus,
    required DateTime cloudUpdatedAt,
    required DateTime? cloudDeletedAt,
  }) {
    if (localUpdatedAt == null || localSyncStatus == null) {
      return cloudDeletedAt != null
          ? CloudMergeDecision.skip
          : CloudMergeDecision.insertCloud;
    }

    const protected = {
      'LOCAL_ONLY',
      'PENDING_UPLOAD',
      'PENDING_DELETE',
      'CONFLICT',
    };

    if (protected.contains(localSyncStatus)) {
      return cloudUpdatedAt.isAfter(localUpdatedAt)
          ? CloudMergeDecision.conflict
          : CloudMergeDecision.keepLocal;
    }

    if (cloudDeletedAt != null) {
      return CloudMergeDecision.skip;
    }

    if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
      return CloudMergeDecision.applyCloud;
    }
    if (cloudUpdatedAt.isBefore(localUpdatedAt)) {
      return CloudMergeDecision.keepLocal;
    }
    return CloudMergeDecision.skip;
  }
}
