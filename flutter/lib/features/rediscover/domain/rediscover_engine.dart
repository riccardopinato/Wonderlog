import 'dart:math' as math;

import 'rediscover_date_utils.dart';
import 'rediscover_models.dart';

final class RediscoverEngine {
  const RediscoverEngine();

  RediscoverFeed buildFeed({
    required DateTime today,
    required List<RediscoverJourney> journeys,
    required List<RediscoverMemory> memories,
    required List<RediscoverPhoto> photos,
  }) {
    final day = DateTime(today.year, today.month, today.day);
    final exact = <RediscoverCard>[
      ..._journeyAnniversaries(day, journeys),
      ..._memoryAnniversaries(day, memories),
      ..._photoAnniversaries(day, photos),
    ];

    final deduped = _distinct(
      exact,
      (card) =>
          card.type.name +
          ':' +
          (card.journeyId ?? '') +
          ':' +
          (card.memoryId ?? '') +
          ':' +
          (card.photoId ?? ''),
    );
    if (deduped.isNotEmpty) {
      return RediscoverFeed(
        cards: deduped,
        generatedForDayKey: RediscoverDateUtils.dayKey(day),
      );
    }

    final nearby = _distinct(
      _nearbyJourneyAnniversaries(day, journeys),
      (card) => card.type.name + ':' + (card.journeyId ?? ''),
    );
    if (nearby.isNotEmpty) {
      return RediscoverFeed(
        cards: nearby,
        generatedForDayKey: RediscoverDateUtils.dayKey(day),
      );
    }

    final fallback = _fallbackMemory(day, memories, journeys);
    return RediscoverFeed(
      cards: fallback == null ? const [] : [fallback],
      generatedForDayKey: RediscoverDateUtils.dayKey(day),
    );
  }

  List<RediscoverCard> _journeyAnniversaries(
    DateTime today,
    List<RediscoverJourney> journeys,
  ) {
    final result = <RediscoverCard>[];
    for (final journey in journeys) {
      final date = RediscoverDateUtils.toLocalDate(journey.startTimestamp);
      if (!RediscoverDateUtils.isSameMonthDay(date, today)) continue;
      final years = RediscoverDateUtils.yearsBetween(date!, today);
      if (years <= 0) continue;
      result.add(
        RediscoverCard(
          id: 'journey-anniversary-' +
              journey.id +
              '-' +
              today.year.toString(),
          type: RediscoverType.journeyAnniversary,
          title: journey.title,
          subtitle:
              years.toString() + (years == 1 ? ' year ago' : ' years ago'),
          journeyId: journey.id,
          memoryId: null,
          photoId: null,
          imageUri: journey.coverPhotoUri,
          timestamp: journey.startTimestamp,
          yearsAgo: years,
        ),
      );
    }
    return result;
  }

  List<RediscoverCard> _nearbyJourneyAnniversaries(
    DateTime today,
    List<RediscoverJourney> journeys,
  ) {
    final result = <RediscoverCard>[];
    for (final journey in journeys) {
      final date = RediscoverDateUtils.toLocalDate(journey.startTimestamp);
      if (date == null) continue;
      final years = today.year - date.year;
      if (years <= 0) continue;

      final anniversary = DateTime(today.year, date.month, date.day);
      final difference =
          RediscoverDateUtils.daysDifference(anniversary, today);
      if (difference < 1 || difference > 3) continue;

      result.add(
        RediscoverCard(
          id: 'journey-nearby-' + journey.id + '-' + today.year.toString(),
          type: RediscoverType.journeyAnniversary,
          title: journey.title,
          subtitle: 'Around this time ' +
              years.toString() +
              (years == 1 ? ' year ago' : ' years ago'),
          journeyId: journey.id,
          memoryId: null,
          photoId: null,
          imageUri: journey.coverPhotoUri,
          timestamp: journey.startTimestamp,
          yearsAgo: years,
        ),
      );
    }
    return result;
  }

  List<RediscoverCard> _memoryAnniversaries(
    DateTime today,
    List<RediscoverMemory> memories,
  ) {
    final result = <RediscoverCard>[];
    for (final memory in memories) {
      final date = RediscoverDateUtils.toLocalDate(memory.timestamp);
      if (!RediscoverDateUtils.isSameMonthDay(date, today)) continue;
      final years = RediscoverDateUtils.yearsBetween(date!, today);
      if (years <= 0) continue;
      var subtitle =
          years.toString() + (years == 1 ? ' year ago' : ' years ago');
      final place = memory.locationName?.trim();
      if (place != null && place.isNotEmpty) subtitle += ' • ' + place;
      result.add(
        RediscoverCard(
          id: 'memory-anniversary-' +
              memory.id +
              '-' +
              today.year.toString(),
          type: RediscoverType.memory,
          title: memory.title,
          subtitle: subtitle,
          journeyId: memory.journeyId,
          memoryId: memory.id,
          photoId: null,
          imageUri: memory.photoUris.isEmpty ? null : memory.photoUris.first,
          timestamp: memory.timestamp,
          yearsAgo: years,
        ),
      );
    }
    return result;
  }

  List<RediscoverCard> _photoAnniversaries(
    DateTime today,
    List<RediscoverPhoto> photos,
  ) {
    final result = <RediscoverCard>[];
    for (final photo in photos) {
      final date = RediscoverDateUtils.toLocalDate(photo.timestamp);
      if (!RediscoverDateUtils.isSameMonthDay(date, today)) continue;
      final years = RediscoverDateUtils.yearsBetween(date!, today);
      if (years <= 0) continue;
      var subtitle =
          years.toString() + (years == 1 ? ' year ago' : ' years ago');
      final place = photo.locationName?.trim();
      if (place != null && place.isNotEmpty) subtitle += ' • ' + place;
      result.add(
        RediscoverCard(
          id: 'photo-anniversary-' +
              photo.id +
              '-' +
              today.year.toString(),
          type: RediscoverType.photo,
          title: 'On this day',
          subtitle: subtitle,
          journeyId: photo.journeyId,
          memoryId: null,
          photoId: photo.id,
          imageUri: photo.localUri,
          timestamp: photo.timestamp,
          yearsAgo: years,
        ),
      );
    }
    return result;
  }

  RediscoverCard? _fallbackMemory(
    DateTime today,
    List<RediscoverMemory> memories,
    List<RediscoverJourney> journeys,
  ) {
    final eligible = memories.where((memory) {
      final date = RediscoverDateUtils.toLocalDate(memory.timestamp);
      if (date == null) return false;
      if (today.difference(date).inDays < 30) return false;
      return memory.title.trim().isNotEmpty ||
          (memory.journalText?.trim().isNotEmpty ?? false) ||
          memory.photoUris.isNotEmpty;
    }).toList(growable: false);
    if (eligible.isEmpty) return null;

    final dayKey = RediscoverDateUtils.dayKey(today);
    final seed = javaStringHash(dayKey);
    eligible.sort(
      (a, b) => math
          .min(
            0x7fffffff,
            javaStringHash(a.id + seed.toString()).abs(),
          )
          .compareTo(
            math.min(
              0x7fffffff,
              javaStringHash(b.id + seed.toString()).abs(),
            ),
          ),
    );
    final selected = eligible.first;

    String? journeyTitle;
    for (final journey in journeys) {
      if (journey.id == selected.journeyId) {
        journeyTitle = journey.title;
        break;
      }
    }

    final location = selected.locationName?.trim();
    final subtitle = journeyTitle != null && journeyTitle.isNotEmpty
        ? 'From ' + journeyTitle
        : location != null && location.isNotEmpty
            ? location
            : 'Resurfaced Memory';

    final memoryDate =
        RediscoverDateUtils.toLocalDate(selected.timestamp) ?? today;
    final years = RediscoverDateUtils.yearsBetween(memoryDate, today);

    return RediscoverCard(
      id: 'memory-fallback-' + selected.id + '-' + dayKey,
      type: RediscoverType.memory,
      title: selected.title,
      subtitle: subtitle,
      journeyId: selected.journeyId,
      memoryId: selected.id,
      photoId: null,
      imageUri: selected.photoUris.isEmpty ? null : selected.photoUris.first,
      timestamp: selected.timestamp,
      yearsAgo: years > 0 ? years : null,
    );
  }

  List<T> _distinct<T>(List<T> values, String Function(T) keyOf) {
    final keys = <String>{};
    return values.where((value) => keys.add(keyOf(value))).toList();
  }
}

int javaStringHash(String value) {
  var hash = 0;
  for (final codeUnit in value.codeUnits) {
    hash = ((31 * hash) + codeUnit) & 0xffffffff;
  }
  return hash >= 0x80000000 ? hash - 0x100000000 : hash;
}
