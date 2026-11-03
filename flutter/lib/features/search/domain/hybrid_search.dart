/// A pure Dart lexical + deterministic *feature-hash* retrieval adapter.
/// No trained neural model, network calls, implicit user visibility or storage.
library;

import 'dart:math' as math;
import 'semantic_embeddings.dart';

final class SearchReferenceException implements Exception {
  const SearchReferenceException(this.code);
  final String code;
  @override
  String toString() => 'SearchReferenceException($code)';
}

final class SearchReferenceDocument {
  SearchReferenceDocument({
    required this.id, required this.text,
    this.revision = 0, this.visible = true, this.deleted = false,
    this.locale, this.tags = const [],
  }) {
    if (id.trim().isEmpty || revision < 0 || text.length > 60000) {
      throw const SearchReferenceException('INVALID_DOCUMENT');
    }
  }

  final String id, text;
  final int revision;
  final bool visible, deleted;
  final String? locale;
  final List<String> tags;
}

final class SearchIndexIdentity {
  SearchIndexIdentity(this.engineId, this.dimensions, this.sourceRevisions) {
    if (engineId.trim().isEmpty || dimensions < 1) {
      throw const SearchReferenceException('INVALID_INDEX_IDENTITY');
    }
  }
  final String engineId;
  final int dimensions;
  final Map<String, int> sourceRevisions;

  void verify(String engineId, int dimensions, Iterable<SearchReferenceDocument> input) {
    if (engineId != this.engineId || dimensions != this.dimensions) {
      throw const SearchReferenceException('INDEX_REBUILD_REQUIRED');
    }
    final active = {for (final d in input) if (!d.deleted) d.id: d.revision};
    if (active.length != sourceRevisions.length ||
        active.entries.any((entry) => sourceRevisions[entry.key] != entry.value)) {
      throw const SearchReferenceException('INDEX_REBUILD_REQUIRED');
    }
  }
}

final class SearchReferenceHit {
  const SearchReferenceHit(this.document, this.score, this.reasons);
  final SearchReferenceDocument document;
  final double score;
  final List<String> reasons;
}

final class SearchReferenceResult {
  const SearchReferenceResult(this.hits, this.mode);
  final List<SearchReferenceHit> hits;
  final String mode;
}

abstract final class HybridReferenceSearch {
  static SearchReferenceResult search({
    required String query,
    required Iterable<SearchReferenceDocument> documents,
    SemanticEmbeddingEngine? semanticEngine = const LocalHashEmbeddingEngine(),
    bool semanticAvailable = true,
    SearchIndexIdentity? storedIndex,
    String? locale,
    int limit = 30,
  }) {
    if (query.length > 1000 || limit < 1 || limit > 300) {
      throw const SearchReferenceException('INVALID_QUERY');
    }
    // Reject conflicting duplicate identities rather than arbitrarily trusting
    // a possibly lower-revision or unauthorized copy.
    final byId = <String, SearchReferenceDocument>{};
    for (final doc in documents) {
      final previous = byId[doc.id];
      if (previous == null || previous.revision < doc.revision) {
        byId[doc.id] = doc;
      } else if (previous.revision == doc.revision &&
          (previous.text != doc.text || previous.visible != doc.visible ||
           previous.deleted != doc.deleted || previous.locale != doc.locale)) {
        throw const SearchReferenceException('CONFLICTING_DOCUMENT_REVISION');
      }
    }
    final canonical = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
    final engine = semanticAvailable ? semanticEngine : null;
    storedIndex?.verify(engine?.id ?? 'lexical', engine?.dimensions ?? 0, canonical);
    final visible = canonical.where((d) =>
        !d.deleted && d.visible && (locale == null || d.locale == null || d.locale == locale))
        .toList(growable: false);
    final tokens = LocalHashEmbeddingEngine.tokenize(query).toSet();
    if (tokens.isEmpty) return SearchReferenceResult(const [], engine == null ? 'lexical' : 'hybrid');
    final qvec = engine?.embed(query);
    if (qvec != null) _checkVector(qvec, engine!.dimensions);
    final matches = <SearchReferenceHit>[];
    for (final doc in visible) {
      final words = LocalHashEmbeddingEngine.tokenize('${doc.text} ${doc.tags.join(' ')}');
      final exactCount = tokens.where(words.contains).length;
      final lexicalScore = exactCount / tokens.length;
      var semanticScore = 0.0;
      if (engine != null) {
        final dvec = engine.embed(doc.text);
        _checkVector(dvec, engine.dimensions);
        semanticScore = math.max(0, LocalHashEmbeddingEngine.cosine(qvec!, dvec));
      }
      final reasons = <String>[];
      if (lexicalScore > 0) reasons.add('lexical');
      // Ignore weak incidental hash collisions. The hashed model is NOT an LLM.
      if (semanticScore >= 0.15) reasons.add('feature_hash');
      if (reasons.isEmpty) continue;
      final score = lexicalScore + semanticScore * 0.5;
      if (!score.isFinite) throw const SearchReferenceException('INVALID_SCORE');
      matches.add(SearchReferenceHit(doc, score, List.unmodifiable(reasons)));
    }
    matches.sort((a, b) {
      final ranked = b.score.compareTo(a.score);
      return ranked != 0 ? ranked : a.document.id.compareTo(b.document.id);
    });
    return SearchReferenceResult(
      List.unmodifiable(matches.take(limit)), engine == null ? 'lexical' : 'hybrid');
  }

  static void _checkVector(List<double> vector, int expectedDimensions) {
    if (vector.length != expectedDimensions || vector.any((v) => !v.isFinite)) {
      throw const SearchReferenceException('INVALID_EMBEDDING');
    }
  }
}
