import 'map_memory_models.dart';

abstract final class MapMemoryFilter {
  static List<MapMemoryItem> apply(
    List<MapMemoryItem> items,
    MapMemoryFilterState filter,
  ) {
    return items.where((item) {
      final dayMatches = filter.selectedDayIndex == null ||
          item.dayIndex == filter.selectedDayIndex;

      final typeMatches = switch (filter.contentFilter) {
        MapMemoryContentFilter.all => true,
        MapMemoryContentFilter.photos =>
          item.type == MapMemoryItemType.photo,
        MapMemoryContentFilter.memories =>
          item.type == MapMemoryItemType.memory,
      };

      return dayMatches && typeMatches;
    }).toList(growable: false);
  }
}
