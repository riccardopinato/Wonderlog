import 'rediscover_models.dart';

final class JourneyReplayBuilder {
  const JourneyReplayBuilder();

  JourneyReplay build({
    required RediscoverJourney journey,
    required List<RediscoverPhoto> photos,
    required List<RediscoverMemory> memories,
  }) {
    final slides = <JourneyReplaySlide>[
      JourneyReplaySlide(
        id: 'cover-' + journey.id,
        type: JourneyReplaySlideType.cover,
        title: journey.title,
        subtitle: journey.destination,
        imageUri: journey.coverPhotoUri,
        timestamp: journey.startTimestamp,
      ),
    ];

    final events = <JourneyReplaySlide>[];

    for (final photo in photos.where((item) => item.journeyId == journey.id)) {
      events.add(
        JourneyReplaySlide(
          id: 'photo-' + photo.id,
          type: JourneyReplaySlideType.photo,
          title: photo.locationName,
          subtitle: null,
          imageUri: photo.localUri,
          timestamp: photo.timestamp,
          photoId: photo.id,
        ),
      );
    }

    for (final memory
        in memories.where((item) => item.journeyId == journey.id)) {
      final text = memory.journalText?.trim();
      final excerpt = text == null || text.isEmpty
          ? null
          : text.length <= 220
              ? text
              : text.substring(0, 220);

      events.add(
        JourneyReplaySlide(
          id: 'memory-' + memory.id,
          type: JourneyReplaySlideType.memory,
          title: memory.title,
          subtitle: excerpt,
          imageUri: memory.photoUris.isEmpty ? null : memory.photoUris.first,
          timestamp: memory.timestamp,
          memoryId: memory.id,
        ),
      );
    }

    events.sort((a, b) {
      if (a.timestamp == null && b.timestamp != null) return 1;
      if (a.timestamp != null && b.timestamp == null) return -1;
      if (a.timestamp != null && b.timestamp != null) {
        final time = a.timestamp!.compareTo(b.timestamp!);
        if (time != 0) return time;
      }
      return a.id.compareTo(b.id);
    });
    slides.addAll(events);

    slides.add(
      JourneyReplaySlide(
        id: 'end-' + journey.id,
        type: JourneyReplaySlideType.end,
        title: journey.title,
        subtitle: journey.photoCount.toString() +
            ' photos • ' +
            journey.memoryCount.toString() +
            ' Memories',
        imageUri: journey.coverPhotoUri,
        timestamp: journey.endTimestamp,
      ),
    );

    return JourneyReplay(
      journeyId: journey.id,
      journeyTitle: journey.title,
      slides: slides,
    );
  }
}
