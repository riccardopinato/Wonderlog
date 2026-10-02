abstract final class JourneyDayResolver {
  static int? resolve(
    DateTime? journeyStartDate,
    DateTime? itemDate,
  ) {
    if (journeyStartDate == null || itemDate == null) return null;
    final start = DateTime(
      journeyStartDate.year,
      journeyStartDate.month,
      journeyStartDate.day,
    );
    final item = DateTime(itemDate.year, itemDate.month, itemDate.day);
    final days = item.difference(start).inDays;
    return days < 0 ? null : days;
  }
}
