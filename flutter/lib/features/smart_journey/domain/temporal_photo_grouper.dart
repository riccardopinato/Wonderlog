import 'smart_journey_models.dart';

final class SmartJourneyDayGroup {
  const SmartJourneyDayGroup({
    required this.date,
    required this.photos,
  });

  final DateTime date;
  final List<SmartJourneySourcePhoto> photos;
}

final class TemporalPhotoGrouper {
  const TemporalPhotoGrouper();

  List<SmartJourneyDayGroup> group(List<SmartJourneySourcePhoto> photos) {
    if (photos.isEmpty) return const [];

    final sorted = photos.where((photo) => photo.included).toList()
      ..sort((a, b) {
        final first = a.effectiveTimestamp;
        final second = b.effectiveTimestamp;
        if (first == null && second != null) return 1;
        if (first != null && second == null) return -1;
        if (first != null && second != null) {
          final time = first.compareTo(second);
          if (time != 0) return time;
        }
        return a.originalIndex.compareTo(b.originalIndex);
      });

    final groups = <String, SmartJourneyDayGroup>{};
    final undated = <SmartJourneySourcePhoto>[];

    for (final photo in sorted) {
      final timestamp = photo.effectiveTimestamp;
      if (timestamp == null) {
        undated.add(photo);
        continue;
      }
      final local = timestamp.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      final key = _key(date);
      final existing = groups[key];
      groups[key] = SmartJourneyDayGroup(
        date: date,
        photos: [...?existing?.photos, photo],
      );
    }

    if (undated.isNotEmpty) {
      final orderedKeys = groups.keys.toList()..sort();
      final fallback = orderedKeys.isEmpty
          ? _dateOnly(DateTime.now())
          : groups[orderedKeys.last]!.date;
      final key = _key(fallback);
      final existing = groups[key];
      groups[key] = SmartJourneyDayGroup(
        date: fallback,
        photos: [...?existing?.photos, ...undated],
      );
    }

    final result = groups.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return result
        .map(
          (group) => SmartJourneyDayGroup(
            date: group.date,
            photos: [...group.photos]
              ..sort((a, b) => a.originalIndex.compareTo(b.originalIndex)),
          ),
        )
        .toList(growable: false);
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _key(DateTime date) =>
      date.year.toString().padLeft(4, '0') +
      '-' +
      date.month.toString().padLeft(2, '0') +
      '-' +
      date.day.toString().padLeft(2, '0');
}
