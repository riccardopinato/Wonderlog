import 'dart:math' as math;

import 'rediscover_engine.dart';
import 'rediscover_models.dart';

abstract final class RediscoverSelectionEngine {
  static List<RediscoverCard> selectForHome(
    RediscoverFeed feed, {
    int maxCards = 5,
  }) {
    if (feed.cards.isEmpty) return const [];

    final seed = javaStringHash(feed.generatedForDayKey);
    final sorted = [...feed.cards]
      ..sort((a, b) {
        final priority = _priority(a).compareTo(_priority(b));
        if (priority != 0) return priority;
        final first =
            math.min(0x7fffffff, javaStringHash(a.id + seed.toString()).abs());
        final second =
            math.min(0x7fffffff, javaStringHash(b.id + seed.toString()).abs());
        return first.compareTo(second);
      });

    final selected = <RediscoverCard>[];
    final journeyCounts = <String, int>{};

    for (final card in sorted) {
      final journeyId = card.journeyId;
      if (journeyId != null) {
        final count = journeyCounts[journeyId] ?? 0;
        if (count >= 2) continue;
        journeyCounts[journeyId] = count + 1;
      }
      selected.add(card);
      if (selected.length >= maxCards) break;
    }

    return selected;
  }

  static RediscoverCard? selectWidgetCard(RediscoverFeed feed) {
    final selected = selectForHome(feed, maxCards: 1);
    return selected.isEmpty ? null : selected.first;
  }

  static int _priority(RediscoverCard card) => switch (card.type) {
        RediscoverType.journeyAnniversary => 1,
        RediscoverType.memory =>
          card.imageUri != null && card.imageUri!.trim().isNotEmpty ? 2 : 3,
        RediscoverType.photo => 4,
        RediscoverType.onThisDay => 5,
      };
}
