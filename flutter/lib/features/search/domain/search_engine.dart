import 'hybrid_search.dart' as golden;
import '../../journeys/domain/journey.dart';
import '../../memories/domain/memory_models.dart';

sealed class WonderlogSearchResult {
  const WonderlogSearchResult();
}

final class JourneySearchResult extends WonderlogSearchResult {
  const JourneySearchResult(this.journey);
  final Journey journey;
}

final class MemorySearchResult extends WonderlogSearchResult {
  const MemorySearchResult(this.memory);
  final MemoryEntry memory;
}

abstract final class WonderlogSearchEngine {
  /// Local search, with optional deterministic feature-hash expansion.
  /// Literal substring matching remains the default to preserve legacy
  /// progressive typing and accent-insensitive partial search.
  static List<WonderlogSearchResult> search({
    required String query,
    required List<Journey> journeys,
    required List<MemoryEntry> memories,
    int limit = 80,
    bool includeRelatedTerms = false,
  }) {
    final normalized = _normalize(query);
    if (normalized.isEmpty || normalized.length > 1000 || limit <= 0) {
      return const [];
    }
    final entries = <(String, String, WonderlogSearchResult)>[];
    for (final journey in journeys) {
      final text = _normalize([
        journey.title, journey.destination, journey.country,
        journey.description,
      ].join(' '));
      if (includeRelatedTerms || text.contains(normalized)) {
        entries.add(('journey:${journey.id}', text,
            JourneySearchResult(journey)));
      }
    }
    for (final memory in memories) {
      final text = _normalize([
        memory.title, memory.journalText, memory.locationName, ...memory.tags,
      ].join(' '));
      if (includeRelatedTerms || text.contains(normalized)) {
        entries.add(('memory:${memory.id}', text,
            MemorySearchResult(memory)));
      }
    }
    if (entries.isEmpty) return const [];
    final candidates = [
      for (final item in entries)
        golden.SearchReferenceDocument(id: item.$1,
          text: item.$2.length > 60000 ? item.$2.substring(0, 60000) : item.$2)
    ];
    final ranked = golden.HybridReferenceSearch.search(
      query: normalized, documents: candidates,
      semanticAvailable: includeRelatedTerms,
      limit: 300,
    );
    final byId = {for (final item in entries) item.$1: item.$3};
    if (includeRelatedTerms) {
      return List.unmodifiable(ranked.hits
          .map((hit) => byId[hit.document.id])
          .whereType<WonderlogSearchResult>()
          .take(limit));
    }
    // Keep partial/stopword-only matches that feature-tokenization drops.
    // The Golden lexical score only orders existing literal matches.
    final weights = {
      for (final hit in ranked.hits) hit.document.id: hit.score,
    };
    final originalOrder = {
      for (var i = 0; i < entries.length; i++) entries[i].$1: i,
    };
    final ordered = [...entries]..sort((a, b) {
      final score = (weights[b.$1] ?? 0).compareTo(weights[a.$1] ?? 0);
      return score != 0 ? score : originalOrder[a.$1]!.compareTo(originalOrder[b.$1]!);
    });
    return List.unmodifiable(ordered.take(limit).map((e) => e.$3));
  }

  static String _normalize(String value) {
    var text = value.toLowerCase().trim();
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };
    replacements.forEach((from, to) => text = text.replaceAll(from, to));
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }
}
