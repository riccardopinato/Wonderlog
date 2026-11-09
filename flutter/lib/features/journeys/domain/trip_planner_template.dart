/// Builds plain editable Journey.description sections; no new trip data owner.
String buildTripPlannerDescription({
  required String ideasHeading,
  required String packingHeading,
  required bool includeIdeas,
  required bool includePacking,
}) {
  final ideas = ideasHeading.trim();
  final packing = packingHeading.trim();
  final sections = <String>[
    if (includeIdeas && ideas.isNotEmpty) '## $ideas',
    if (includePacking && packing.isNotEmpty) '## $packing',
  ];
  return sections.join('\n\n');
}
