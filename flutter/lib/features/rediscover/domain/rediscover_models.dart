enum RediscoverType {
  onThisDay,
  journeyAnniversary,
  memory,
  photo,
}

final class RediscoverPhoto {
  const RediscoverPhoto({
    required this.id,
    required this.journeyId,
    required this.localUri,
    required this.timestamp,
    this.locationName,
  });

  final String id;
  final String journeyId;
  final String localUri;
  final DateTime? timestamp;
  final String? locationName;
}

final class RediscoverMemory {
  const RediscoverMemory({
    required this.id,
    required this.journeyId,
    required this.title,
    required this.journalText,
    required this.timestamp,
    required this.locationName,
    required this.photoUris,
  });

  final String id;
  final String journeyId;
  final String title;
  final String? journalText;
  final DateTime? timestamp;
  final String? locationName;
  final List<String> photoUris;
}

final class RediscoverJourney {
  const RediscoverJourney({
    required this.id,
    required this.title,
    required this.destination,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.coverPhotoUri,
    required this.photoCount,
    required this.memoryCount,
  });

  final String id;
  final String title;
  final String? destination;
  final DateTime? startTimestamp;
  final DateTime? endTimestamp;
  final String? coverPhotoUri;
  final int photoCount;
  final int memoryCount;
}

final class RediscoverCard {
  const RediscoverCard({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.journeyId,
    required this.memoryId,
    required this.photoId,
    required this.imageUri,
    required this.timestamp,
    this.yearsAgo,
  });

  final String id;
  final RediscoverType type;
  final String title;
  final String? subtitle;
  final String? journeyId;
  final String? memoryId;
  final String? photoId;
  final String? imageUri;
  final DateTime? timestamp;
  final int? yearsAgo;
}

final class RediscoverFeed {
  const RediscoverFeed({
    required this.cards,
    required this.generatedForDayKey,
  });

  final List<RediscoverCard> cards;
  final String generatedForDayKey;
}

enum JourneyReplaySlideType { cover, photo, memory, place, end }

final class JourneyReplaySlide {
  const JourneyReplaySlide({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.imageUri,
    required this.timestamp,
    this.memoryId,
    this.photoId,
  });

  final String id;
  final JourneyReplaySlideType type;
  final String? title;
  final String? subtitle;
  final String? imageUri;
  final DateTime? timestamp;
  final String? memoryId;
  final String? photoId;
}

final class JourneyReplay {
  const JourneyReplay({
    required this.journeyId,
    required this.journeyTitle,
    required this.slides,
  });

  final String journeyId;
  final String journeyTitle;
  final List<JourneyReplaySlide> slides;
}
