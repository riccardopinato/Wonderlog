/// Builds plain editable Journey.description sections; no new trip data owner.
String buildTripPlannerDescription({
  required String ideasHeading,
  required String packingHeading,
  required bool includeIdeas,
  required bool includePacking,
}) {
  final sections = <String>[
    if (includeIdeas) '## ${ideasHeading.trim()}',
    if (includePacking) '## ${packingHeading.trim()}',
  ];
  return sections.join('\n\n');
}
