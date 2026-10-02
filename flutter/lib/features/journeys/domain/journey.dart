final class Journey {
  const Journey({
    required this.id,
    required this.title,
    required this.destination,
    required this.country,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.favorite,
    required this.archived,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String destination;
  final String country;
  final DateTime startDate;
  final DateTime endDate;
  final String description;
  final double latitude;
  final double longitude;
  final bool favorite;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;
}
