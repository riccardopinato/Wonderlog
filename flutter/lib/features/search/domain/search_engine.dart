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
  static List<WonderlogSearchResult> search({
    required String query,
    required List<Journey> journeys,
    required List<MemoryEntry> memories,
    int limit = 80,
  }) {
    final normalized = _normalize(query);
    if (normalized.isEmpty) return const [];

    final result = <WonderlogSearchResult>[];

    for (final journey in journeys) {
      final haystack = _normalize(
        [
          journey.title,
          journey.destination,
          journey.country,
          journey.description,
        ].join(' '),
      );
      if (haystack.contains(normalized)) {
        result.add(JourneySearchResult(journey));
      }
    }

    for (final memory in memories) {
      final haystack = _normalize(
        [
          memory.title,
          memory.journalText,
          memory.locationName,
          ...memory.tags,
        ].join(' '),
      );
      if (haystack.contains(normalized)) {
        result.add(MemorySearchResult(memory));
      }
    }

    return result.take(limit).toList(growable: false);
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
