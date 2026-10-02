abstract final class RediscoverDateUtils {
  static DateTime? toLocalDate(DateTime? timestamp) {
    if (timestamp == null) return null;
    final local = timestamp.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static bool isSameMonthDay(DateTime? candidate, DateTime today) =>
      candidate != null &&
      candidate.month == today.month &&
      candidate.day == today.day;

  static int yearsBetween(DateTime past, DateTime today) {
    if (past.isAfter(today)) return 0;
    return today.year - past.year;
  }

  static int daysDifference(DateTime first, DateTime second) =>
      second.difference(first).inDays.abs();

  static String dayKey(DateTime date) =>
      date.year.toString().padLeft(4, '0') +
      '-' +
      date.month.toString().padLeft(2, '0') +
      '-' +
      date.day.toString().padLeft(2, '0');

  static DateTime? parseIsoDate(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
}
